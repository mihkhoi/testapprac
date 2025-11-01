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
            // Lấy danh sách doanh nghiệp + collectors bên trong
            // Chỉ admin mới được coi toàn bộ
            app.MapGet("/api/companies",
                [Authorize(Roles = "admin")]
                async (AppDb db) =>
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
                }
            );

            // Tạo công ty mới
            // body: { "name":"...", "contactPhone":"...", "address":"..." }
            app.MapPost("/api/companies",
                [Authorize(Roles = "admin")]
                async (AppDb db, CollectorCompany input) =>
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
                }
            );

            // Xoá công ty
            app.MapDelete("/api/companies/{id:int}",
                [Authorize(Roles = "admin")]
                async (AppDb db, int id) =>
                {
                    var co = await db.CollectorCompanies
                        .Include(c => c.Collectors)
                        .FirstOrDefaultAsync(c => c.Id == id);

                    if (co is null) return Results.NotFound();

                    // nếu xài cascade, EF sẽ xoá collectors theo rule FK;
                    // nếu không cascade thì bạn có thể bắt buộc không cho xoá khi còn collector.
                    db.CollectorCompanies.Remove(co);
                    await db.SaveChangesAsync();
                    return Results.NoContent();
                }
            );

            // Tạo collector mới trong 1 công ty
            // body: { "companyId":1, "fullName":"...", "phone":"..." }
            app.MapPost("/api/collectors",
                [Authorize(Roles = "admin")]
                async (AppDb db, Collector input) =>
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
                }
            );

            // Xoá collector
            app.MapDelete("/api/collectors/{id:int}",
                [Authorize(Roles = "admin")]
                async (AppDb db, int id) =>
                {
                    var col = await db.Collectors.FindAsync(id);
                    if (col is null) return Results.NotFound();

                    db.Collectors.Remove(col);
                    await db.SaveChangesAsync();
                    return Results.NoContent();
                }
            );
        }
    }
}
