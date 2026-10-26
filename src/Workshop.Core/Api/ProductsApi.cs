using System;
using Workshop.Core.Data;
using Workshop.Core.Json;
using Workshop.Core.Models;

namespace Workshop.Core.Api
{
    public class ApiResult
    {
        public int StatusCode { get; set; }
        public string Json { get; set; }
        public string Location { get; set; }
    }

    /// <summary>
    /// Framework-neutral API logic. The Web Forms project exposes it through IHttpHandlers,
    /// the MVC project through controllers.
    /// </summary>
    public static class ProductsApi
    {
        public static ApiResult Health(string app)
        {
            return Ok(JsonHelper.Serialize(new
            {
                status = "ok",
                app = app,
                runtime = RuntimeInfo.Describe(),
                os = Environment.OSVersion.ToString(),
                host = Environment.MachineName,
                newtonsoft = RuntimeInfo.NewtonsoftVersion(),
                time = DateTime.UtcNow.ToString("o")
            }));
        }

        public static ApiResult Handle(string httpMethod, string id, string body)
        {
            switch ((httpMethod ?? "").ToUpperInvariant())
            {
                case "GET":
                    if (string.IsNullOrEmpty(id))
                        return Ok(JsonHelper.Serialize(ProductRepository.All()));
                    int productId;
                    var found = int.TryParse(id, out productId) ? ProductRepository.Find(productId) : null;
                    return found == null ? Error(404, "not found") : Ok(JsonHelper.Serialize(found));

                case "POST":
                    var input = JsonHelper.Deserialize<Product>(body);
                    if (input == null || string.IsNullOrWhiteSpace(input.Name) || input.Price < 0)
                        return Error(400, "name and non-negative price are required");
                    var created = ProductRepository.Add(input.Name.Trim(), input.Price);
                    return new ApiResult
                    {
                        StatusCode = 201,
                        Json = JsonHelper.Serialize(created),
                        Location = "api/products?id=" + created.Id
                    };

                default:
                    return Error(405, "method not allowed");
            }
        }

        private static ApiResult Ok(string json)
        {
            return new ApiResult { StatusCode = 200, Json = json };
        }

        private static ApiResult Error(int code, string message)
        {
            return new ApiResult { StatusCode = code, Json = JsonHelper.Serialize(new { error = message }) };
        }
    }
}
