using Microsoft.EntityFrameworkCore;
using ScrapApi.Data;
using ScrapApi.Models;
using ScrapApi.Auth;

namespace ScrapApi.Endpoints
{
    public static class AuthEndpoints
    {
        public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
        {
            // Đăng ký tài khoản mới
            // body: { "username":"...", "password":"...", "role":"customer|collector|admin", "customerId":1, "collectorId":null }
            app.MapPost("/api/auth/register", async (AppDb db, RegisterDto dto) =>
            {
                // check trùng username
                if (await db.Users.AnyAsync(u => u.Username == dto.Username))
                    return Results.BadRequest("Username tồn tại");

                var user = new User
                {
                    Username     = dto.Username,
                    PasswordHash = AuthUtils.HashPassword(dto.Password),
                    Role         = dto.Role ?? "customer",
                    CustomerId   = dto.CustomerId,
                    CollectorId  = dto.CollectorId
                };

                db.Users.Add(user);
                await db.SaveChangesAsync();

                return Results.Created(
                    $"/api/users/{user.Id}",
                    new { user.Id, user.Username, user.Role }
                );
            });

            // Đăng nhập -> trả token JWT
            // body: { "username":"...", "password":"..." }
            app.MapPost("/api/auth/login", async (AppDb db, LoginDto dto, IConfiguration config) =>
            {
                var hash = AuthUtils.HashPassword(dto.Password);

                var user = await db.Users
                    .FirstOrDefaultAsync(u =>
                        u.Username == dto.Username &&
                        u.PasswordHash == hash);

                if (user is null)
                    return Results.Unauthorized();

                var jwtKey    = config["Jwt:Key"]    ?? "dev_temp_secret_123456";
                var jwtIssuer = config["Jwt:Issuer"] ?? "ScrapApi";

                var token = AuthUtils.CreateJwtToken(
                    username:    user.Username,
                    role:        user.Role,
                    issuer:      jwtIssuer,
                    key:         jwtKey,
                    customerId:  user.CustomerId,
                    collectorId: user.CollectorId
                );

                return Results.Ok(new
                {
                    token,
                    role        = user.Role,
                    customerId  = user.CustomerId,
                    collectorId = user.CollectorId
                });
            });
        }
    }
}
