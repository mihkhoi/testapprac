namespace ScrapApi.Auth
{
    // Dùng khi đăng ký tài khoản mới
    // body ví dụ:
    // {
    //   "username": "alice",
    //   "password": "123456",
    //   "role": "customer",
    //   "customerId": 3,
    //   "collectorId": null
    // }
    public record RegisterDto(
        string Username,
        string Password,
        string? Role,
        int? CustomerId,
        int? CollectorId
    );

    // Dùng khi đăng nhập
    // body ví dụ:
    // {
    //   "username": "alice",
    //   "password": "123456"
    // }
    public record LoginDto(
        string Username,
        string Password
    );
}
