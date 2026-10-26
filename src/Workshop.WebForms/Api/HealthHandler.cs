using System.Web;
using Workshop.Core.Api;

namespace Workshop.WebForms.Api
{
    /// <summary>GET api/health</summary>
    public class HealthHandler : IHttpHandler
    {
        public bool IsReusable { get { return true; } }

        public void ProcessRequest(HttpContext context)
        {
            var result = ProductsApi.Health("webforms");
            context.Response.StatusCode = result.StatusCode;
            context.Response.ContentType = "application/json";
            context.Response.Write(result.Json);
        }
    }
}
