using System.IO;
using System.Web;
using Workshop.Core.Api;

namespace Workshop.WebForms.Api
{
    /// <summary>
    /// Classic ASP.NET "API": a plain IHttpHandler mapped in Web.config.
    ///   GET  api/products          list
    ///   GET  api/products?id=2     one product (404 if missing)
    ///   POST api/products          create, body {"name":"Mouse","price":19.9}
    /// </summary>
    public class ProductsHandler : IHttpHandler
    {
        public bool IsReusable { get { return true; } }

        public void ProcessRequest(HttpContext context)
        {
            string body = null;
            if (context.Request.HttpMethod == "POST")
            {
                using (var reader = new StreamReader(context.Request.InputStream))
                    body = reader.ReadToEnd();
            }

            var result = ProductsApi.Handle(context.Request.HttpMethod, context.Request.QueryString["id"], body);

            context.Response.StatusCode = result.StatusCode;
            context.Response.ContentType = "application/json";
            if (result.Location != null) context.Response.AddHeader("Location", result.Location);
            context.Response.Write(result.Json);
        }
    }
}
