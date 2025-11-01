using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;

namespace ScrapApi.Endpoints
{
    public static class CompaniesEndpoints
    {
        public static void MapCompaniesEndpoints(this IEndpointRouteBuilder app)
        {
            // Group public API /api/companies dành cho quản lý công ty/collector
            // (theo thiết kế ban đầu của bạn yêu cầu admin luôn,
            // nên mình gắn RequireRole("admin") vào group này luôn cho gọn)

            var companiesGroup = app.MapGroup("/api/companies")
                .RequireAuthorization(policy => policy.RequireRole("admin"));

            // GET /api/companies
            companiesGroup.MapGet("/", async (AppDb db) =>
            {
                var data = await db.CollectorCompanies
                    .Include(c => c.Collectors)
                    .Select(c => new
                    {
                        c.Id,
                        c.Name,
                        c.ContactPhone,
                        c.Address,
                        collectors = c.Collectors.Select(col => new
                        {
                            col.Id,
                            col.FullName,
                            col.Phone,
                            col.CompanyId
                        }).ToList()
                    })
                    .ToListAsync();

                return Results.Ok(data);
            });

            // POST /api/companies
            // body: { "name":"...", "contactPhone":"...", "address":"..." }
            companiesGroup.MapPost("/", async (AppDb db, CollectorCompany input) =>
            {
                var co = new CollectorCompany
                {
                    Name         = input.Name,
                    ContactPhone = input.ContactPhone,
                    Address      = input.Address
                };

                db.CollectorCompanies.Add(co);
                await db.SaveChangesAsync();

                return Results.Created($"/api/companies/{co.Id}", co);
            });

            // DELETE /api/companies/{id}
            companiesGroup.MapDelete("/{id:int}", async (AppDb db, int id) =>
            {
                var co = await db.CollectorCompanies
                    .Include(c => c.Collectors)
                    .FirstOrDefaultAsync(c => c.Id == id);

                if (co is null) return Results.NotFound();

                db.CollectorCompanies.Remove(co);
                await db.SaveChangesAsync();
                return Results.NoContent();
            });

            // POST /api/collectors (tạo collector)
            companiesGroup.MapPost("/collectors", async (AppDb db, Collector input) =>
            {
                var col = new Collector
                {
                    FullName  = input.FullName,
                    Phone     = input.Phone,
                    CompanyId = input.CompanyId,
                };

                db.Collectors.Add(col);
                await db.SaveChangesAsync();

                return Results.Created($"/api/collectors/{col.Id}", col);
            });

            // DELETE /api/collectors/{id}
            companiesGroup.MapDelete("/collectors/{id:int}", async (AppDb db, int id) =>
            {
                var col = await db.Collectors.FindAsync(id);
                if (col is null) return Results.NotFound();

                db.Collectors.Remove(col);
                await db.SaveChangesAsync();
                return Results.NoContent();
            });
        }
    }
}
