using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;
using ScrapApi.Utils;

namespace ScrapApi.Endpoints
{
    public static class DispatchEndpoints
    {
        public static void MapDispatchEndpoints(this IEndpointRouteBuilder app)
        {
            // LIVE MAP data cho màn hình bản đồ điều phối
            app.MapGet("/api/dispatch/live", async (AppDb db) =>
            {
                var collectors = await db.Collectors
                    .Select(c => new
                    {
                        c.Id,
                        c.FullName,
                        c.Phone,
                        c.CurrentLat,
                        c.CurrentLng,
                        c.LastSeenAt
                    })
                    .ToListAsync();

                var pendingJobs = await db.PickupRequests
                    .Where(p => p.Status == PickupStatus.Pending)
                    .Select(p => new
                    {
                        p.Id,
                        p.ScrapType,
                        p.QuantityKg,
                        p.Lat,
                        p.Lng,
                        p.CreatedAt,
                        CustomerName  = p.Customer != null ? p.Customer.FullName : null,
                        CustomerPhone = p.Customer != null ? p.Customer.Phone    : null
                    })
                    .ToListAsync();

                return Results.Ok(new
                {
                    collectors,
                    pendingJobs
                });
            });

            // Gán job Pending cho collector gần nhất
            app.MapPost("/api/pickups/{id:int}/dispatch-nearest", async (
                AppDb db,
                int id,
                double jobLat,
                double jobLng,
                double? radiusKm,
                int? companyId) =>
            {
                var req = await db.PickupRequests.FindAsync(id);
                if (req is null)
                    return Results.NotFound("Pickup not found");

                if (req.Status != PickupStatus.Pending)
                    return Results.BadRequest("Only Pending can be dispatched");

                // lọc collector theo công ty nếu có
                var collectors = companyId is null
                    ? await db.Collectors.AsNoTracking().ToListAsync()
                    : await db.Collectors
                        .Where(c => c.CompanyId == companyId)
                        .AsNoTracking()
                        .ToListAsync();

                if (collectors.Count == 0)
                    return Results.BadRequest("No collectors available");

                // tính khoảng cách từ jobLat/jobLng tới từng collector có toạ độ
                var candidates = collectors
                    .Where(c => c.CurrentLat != null && c.CurrentLng != null)
                    .Select(c => new
                    {
                        Collector = c,
                        DistKm = GeoUtils.Haversine(
                            jobLat,
                            jobLng,
                            c.CurrentLat!.Value,
                            c.CurrentLng!.Value
                        )
                    })
                    .OrderBy(x => x.DistKm)
                    .ToList();

                var chosen = candidates.FirstOrDefault();

                // fallback nếu không ai có toạ độ -> chọn collector đầu tiên bất kỳ
                if (chosen is null)
                {
                    var any = collectors.First();
                    req.Status = PickupStatus.Accepted;
                    req.AcceptedByCollectorId = any.Id;
                    await db.SaveChangesAsync();

                    return Results.Ok(new
                    {
                        assignedTo = any.Id,
                        distanceKm = (double?)null,
                        note       = "No collector position known; assigned first collector."
                    });
                }

                var nearest    = chosen.Collector;
                var distKm     = chosen.DistKm;
                var radius     = radiusKm ?? 10.0;

                if (distKm > radius)
                {
                    return Results.BadRequest(
                        $"Nearest collector is {distKm:0.00} km away (> {radius:0.##} km)"
                    );
                }

                req.Status = PickupStatus.Accepted;
                req.AcceptedByCollectorId = nearest.Id;
                await db.SaveChangesAsync();

                return Results.Ok(new
                {
                    assignedTo = nearest.Id,
                    distanceKm = distKm
                });
            });
        }
    }
}
