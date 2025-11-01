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
            // /api/auth/register
            app.MapPost("/api/auth/register", async (AppDb db, RegisterDto dto) =>
            {
                if (await db.Users.AnyAsync(u => u.Username == dto.Username))
                    return Results.BadRequest("Username tồn tại");

                var user = new User
                {
                    Username     = dto.Username,
                    // lưu dạng hash chuẩn cho tài khoản mới
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

            // /api/auth/login
            app.MapPost("/api/auth/login", async (AppDb db, LoginDto dto, IConfiguration config) =>
            {
                // 1) thử kiểu HASH (cho user tạo mới)
                var hash = AuthUtils.HashPassword(dto.Password);

                var user = await db.Users.FirstOrDefaultAsync(u =>
                    u.Username == dto.Username &&
                    u.PasswordHash == hash
                );

                // 2) nếu không có -> thử password plain (cho user seed ban đầu)
                if (user is null)
                {
                    user = await db.Users.FirstOrDefaultAsync(u =>
                        u.Username == dto.Username &&
                        u.PasswordHash == dto.Password
                    );
                }

                if (user is null)
                {
                    return Results.Unauthorized();
                }

                // Lấy key & issuer từ config hoặc fallback siêu dài
                var jwtKey = config["Jwt:Key"]
                    ?? "THIS_IS_A_DEMO_SUPER_LONG_SECRET_KEY_1234567890_ABCD!!";
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
