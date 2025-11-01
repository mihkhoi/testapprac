using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class PickupsEndpoints
    {
        public static void MapPickupsEndpoints(this IEndpointRouteBuilder app)
        {
            // lấy danh sách yêu cầu thu gom, có filter
            app.MapGet("/api/pickups", async (AppDb db, int? status, int? collectorId, int? customerId) =>
            {
                var q = db.PickupRequests
                    .Include(p => p.Customer)
                    .Include(p => p.AcceptedByCollector)
                    .AsQueryable();

                if (status is not null)
                    q = q.Where(p => (int)p.Status == status);

                if (collectorId is not null)
                    q = q.Where(p => p.AcceptedByCollectorId == collectorId);

                if (customerId is not null)
                    q = q.Where(p => p.CustomerId == customerId);

                return await q
                    .OrderByDescending(p => p.CreatedAt)
                    .ToListAsync();
            });

            // tạo pickup mới (khách đặt lịch)
            app.MapPost("/api/pickups", async (AppDb db, PickupRequest req) =>
            {
                if (req.QuantityKg <= 0)
                    return Results.BadRequest("QuantityKg must be > 0");
                if (string.IsNullOrWhiteSpace(req.ScrapType))
                    return Results.BadRequest("ScrapType is required");

                req.Status = PickupStatus.Pending;
                db.PickupRequests.Add(req);
                await db.SaveChangesAsync();

                return Results.Created($"/api/pickups/{req.Id}", req);
            });

            // collector nhận job
            app.MapPost("/api/pickups/{id:int}/accept", async (AppDb db, int id, int collectorId) =>
            {
                var req = await db.PickupRequests.FindAsync(id);
                if (req is null) return Results.NotFound();

                var col = await db.Collectors.FindAsync(collectorId);
                if (col is null) return Results.BadRequest("Collector not found");

                if (req.Status != PickupStatus.Pending)
                    return Results.BadRequest("Only pending requests can be accepted");

                req.Status = PickupStatus.Accepted;
                req.AcceptedByCollectorId = collectorId;
                await db.SaveChangesAsync();

                return Results.Ok(req);
            });

            // đổi trạng thái pickup
            app.MapPost("/api/pickups/{id:int}/status", async (AppDb db, int id, PickupStatus status) =>
            {
                var req = await db.PickupRequests.FindAsync(id);
                if (req is null) return Results.NotFound();

                req.Status = status;
                await db.SaveChangesAsync();

                return Results.Ok(req);
            });
        }
    }
}
