using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class CustomersEndpoints
    {
        public static void MapCustomersEndpoints(this IEndpointRouteBuilder app)
        {
            app.MapGet("/api/customers", async (AppDb db) =>
                await db.Customers.AsNoTracking().ToListAsync()
            );

            app.MapGet("/api/customers/{id:int}", async (AppDb db, int id) =>
                await db.Customers.FindAsync(id) is { } c
                    ? Results.Ok(c)
                    : Results.NotFound()
            );

            app.MapPost("/api/customers", async (AppDb db, Customer c) =>
            {
                db.Customers.Add(c);
                await db.SaveChangesAsync();
                return Results.Created($"/api/customers/{c.Id}", c);
            });

            app.MapPut("/api/customers/{id:int}", async (AppDb db, int id, Customer input) =>
            {
                var c = await db.Customers.FindAsync(id);
                if (c is null) return Results.NotFound();

                c.FullName = input.FullName;
                c.Phone    = input.Phone;
                c.Address  = input.Address;
                c.LastLat  = input.LastLat;
                c.LastLng  = input.LastLng;

                await db.SaveChangesAsync();
                return Results.Ok(c);
            });

            app.MapDelete("/api/customers/{id:int}", async (AppDb db, int id) =>
            {
                var c = await db.Customers.FindAsync(id);
                if (c is null) return Results.NotFound();

                db.Customers.Remove(c);
                await db.SaveChangesAsync();
                return Results.NoContent();
            });

            // cập nhật vị trí khách (LastLat/LastLng)
            app.MapPost("/api/customers/{id:int}/location",
                async (AppDb db, int id, double lat, double lng) =>
                {
                    var c = await db.Customers.FindAsync(id);
                    if (c is null) return Results.NotFound();

                    c.LastLat = lat;
                    c.LastLng = lng;
                    await db.SaveChangesAsync();

                    return Results.Ok(new { c.Id, c.LastLat, c.LastLng });
                });
        }
    }
}
