using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class ManagementEndpoints
    {
        public static void MapManagementEndpoints(this IEndpointRouteBuilder app)
        {
            // GET all companies + collectors
            app.MapGet("/api/companies", async (AppDb db) =>
            {
                var data = await db.CollectorCompanies
                    .Include(c => c.Collectors)
                    .Select(c => new {
                        c.Id,
                        c.Name,
                        c.ContactPhone,
                        c.Address,
                        collectors = c.Collectors.Select(co => new {
                            co.Id,
                            co.FullName,
                            co.Phone,
                            co.CompanyId
                        }).ToList()
                    })
                    .ToListAsync();

                return Results.Ok(data);
            });

            // POST create company
            app.MapPost("/api/companies", async (AppDb db, CollectorCompany co) =>
            {
                db.CollectorCompanies.Add(co);
                await db.SaveChangesAsync();
                return Results.Created($"/api/companies/{co.Id}", co);
            });

            // PUT update company
            app.MapPut("/api/companies/{id:int}", async (AppDb db, int id, CollectorCompany input) =>
            {
                var co = await db.CollectorCompanies.FindAsync(id);
                if (co == null) return Results.NotFound();

                co.Name = input.Name;
                co.ContactPhone = input.ContactPhone;
                co.Address = input.Address;

                await db.SaveChangesAsync();
                return Results.Ok(co);
            });

            // DELETE company
            app.MapDelete("/api/companies/{id:int}", async (AppDb db, int id) =>
            {
                var co = await db.CollectorCompanies
                    .Include(c => c.Collectors)
                    .FirstOrDefaultAsync(c => c.Id == id);
                if (co == null) return Results.NotFound();

                // xoá luôn collectors con hoặc check ràng buộc tuỳ bạn
                db.Collectors.RemoveRange(co.Collectors);
                db.CollectorCompanies.Remove(co);

                await db.SaveChangesAsync();
                return Results.NoContent();
            });

            // POST create collector
            app.MapPost("/api/collectors", async (AppDb db, Collector c) =>
            {
                db.Collectors.Add(c);
                await db.SaveChangesAsync();
                return Results.Created($"/api/collectors/{c.Id}", c);
            });

            // PUT update collector
            app.MapPut("/api/collectors/{id:int}", async (AppDb db, int id, Collector input) =>
            {
                var c = await db.Collectors.FindAsync(id);
                if (c == null) return Results.NotFound();

                c.FullName = input.FullName;
                c.Phone = input.Phone;
                c.CompanyId = input.CompanyId;

                await db.SaveChangesAsync();
                return Results.Ok(c);
            });

            // DELETE collector
            app.MapDelete("/api/collectors/{id:int}", async (AppDb db, int id) =>
            {
                var c = await db.Collectors.FindAsync(id);
                if (c == null) return Results.NotFound();

                db.Collectors.Remove(c);
                await db.SaveChangesAsync();
                return Results.NoContent();
            });
        }
    }
}
