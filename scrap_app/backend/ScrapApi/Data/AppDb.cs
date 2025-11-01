using Microsoft.EntityFrameworkCore;
using ScrapApi.Models;

namespace ScrapApi.Data
{
    public class AppDb : DbContext
    {
        public AppDb(DbContextOptions<AppDb> options) : base(options) { }

        // Các bảng
        public DbSet<Customer> Customers => Set<Customer>();
        public DbSet<CollectorCompany> CollectorCompanies => Set<CollectorCompany>();
        public DbSet<Collector> Collectors => Set<Collector>();
        public DbSet<PickupRequest> PickupRequests => Set<PickupRequest>();
        public DbSet<ScrapListing> ScrapListings => Set<ScrapListing>();
        public DbSet<User> Users => Set<User>(); // bảng user mới

        protected override void OnModelCreating(ModelBuilder b)
        {
            // 1. Customer (1) -> (n) PickupRequest
            b.Entity<Customer>()
             .HasMany(x => x.PickupRequests)
             .WithOne(x => x.Customer!)
             .HasForeignKey(x => x.CustomerId)
             .OnDelete(DeleteBehavior.Cascade);

            // 2. CollectorCompany (1) -> (n) Collector
            //
            // Quan hệ này EF Core tự hiểu được nhờ:
            // - Collector has int CompanyId
            // - Collector has CollectorCompany? Company
            // - CollectorCompany has List<Collector> Collectors
            //
            // => Không cần cấu hình thủ công .HasMany<Collector>("Collectors")... như lúc nãy
            //
            // Nếu muốn ghi rõ cho dễ đọc (optional, không bắt buộc), bạn có thể làm kiểu strongly-typed như vầy:
            b.Entity<CollectorCompany>()
             .HasMany(cc => cc.Collectors)
             .WithOne(c => c.Company!)
             .HasForeignKey(c => c.CompanyId)
             .OnDelete(DeleteBehavior.Cascade);

            // 3. Collector (1) -> (n) PickupRequest.AcceptedByCollector
            b.Entity<Collector>()
             .HasMany(x => x.AcceptedRequests)
             .WithOne(r => r.AcceptedByCollector!)
             .HasForeignKey(r => r.AcceptedByCollectorId)
             .OnDelete(DeleteBehavior.SetNull);

            // 4. User -> Customer (optional)
            b.Entity<User>()
             .HasOne(u => u.Customer)
             .WithMany() // cho phép 1 khách có nhiều tài khoản nếu sau này muốn
             .HasForeignKey(u => u.CustomerId)
             .OnDelete(DeleteBehavior.SetNull);

            // 5. User -> Collector (optional)
            b.Entity<User>()
             .HasOne(u => u.Collector)
             .WithMany() // tương tự
             .HasForeignKey(u => u.CollectorId)
             .OnDelete(DeleteBehavior.SetNull);
        }
    }

    public static class SeedData
    {
        public static async Task InitAsync(AppDb db)
        {
            // Seed công ty + collector demo
            if (!db.CollectorCompanies.Any())
            {
                var co = new CollectorCompany
                {
                    Name = "GreenCycle Co.",
                    ContactPhone = "0909-000-111",
                    Address = "HCM"
                };

                db.CollectorCompanies.Add(co);

                db.Collectors.AddRange(
                    new Collector
                    {
                        FullName = "Nguyễn Văn A",
                        Phone = "0901-111-222",
                        Company = co
                    },
                    new Collector
                    {
                        FullName = "Trần Thị B",
                        Phone = "0902-333-444",
                        Company = co
                    }
                );
            }

            // Seed khách demo
            if (!db.Customers.Any())
            {
                db.Customers.AddRange(
                    new Customer
                    {
                        FullName = "Khách 1",
                        Phone = "0987-000-001",
                        Address = "Q1"
                    },
                    new Customer
                    {
                        FullName = "Khách 2",
                        Phone = "0987-000-002",
                        Address = "Q3"
                    }
                );
            }

            // Seed listing demo
            if (!db.ScrapListings.Any())
            {
                db.ScrapListings.Add(new ScrapListing
                {
                    Title = "Nhựa PET 200kg",
                    Description = "Bao sạch",
                    PricePerKg = 7000,
                    Lat = 10.78,
                    Lng = 106.68,
                    CreatedAt = DateTime.UtcNow
                });
            }

            // Seed user admin demo
            if (!db.Users.Any())
            {
                db.Users.Add(new User
                {
                    Username = "admin",
                    PasswordHash = ScrapApi.Auth.AuthUtils.HashPassword("admin123"),
                    Role = "admin",
                    // CustomerId = null,
                    // CollectorId = null
                });
            }

            await db.SaveChangesAsync();
        }
    }
}
