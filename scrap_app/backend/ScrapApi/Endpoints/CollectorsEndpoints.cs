using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class CollectorsEndpoints
    {
        public static void MapCollectorsEndpoints(this IEndpointRouteBuilder app)
        {
            // Collector gửi GPS hiện tại để cập nhật CurrentLat/CurrentLng
            app.MapPost("/api/collectors/{id:int}/location", async (AppDb db, int id, double lat, double lng) =>
            {
                var c = await db.Collectors.FindAsync(id);
                if (c is null) return Results.NotFound();

                c.CurrentLat = lat;
                c.CurrentLng = lng;
                c.LastSeenAt = DateTime.UtcNow;

                await db.SaveChangesAsync();
                return Results.Ok(new
                {
                    c.Id,
                    c.CurrentLat,
                    c.CurrentLng,
                    c.LastSeenAt
                });
            });

            // Lấy pickup của riêng collector này ("việc của tôi")
            app.MapGet("/api/collectors/{id:int}/pickups", async (AppDb db, int id, int? status) =>
            {
                var q = db.PickupRequests
                    .Include(p => p.Customer)
                    .Where(p => p.AcceptedByCollectorId == id);

                if (status is not null)
                    q = q.Where(p => (int)p.Status == status);

                return await q
                    .OrderByDescending(p => p.CreatedAt)
                    .ToListAsync();
            });
        }
    }
}
