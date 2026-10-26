using System.IO;
using System.Web.Mvc;
using Workshop.Core.Api;

namespace Workshop.Mvc.Controllers
{
    /// <summary>
    /// JSON API implemented as a plain MVC controller (the classic, pre-Web API approach).
    ///   GET  api/products, GET api/products/2 (or ?id=2), POST api/products
    /// </summary>
    public class ProductsApiController : Controller
    {
        public ActionResult Index(string id)
        {
            string body = null;
            if (Request.HttpMethod == "POST")
            {
                using (var reader = new StreamReader(Request.InputStream))
                    body = reader.ReadToEnd();
            }

            var result = ProductsApi.Handle(Request.HttpMethod, id, body);

            Response.StatusCode = result.StatusCode;
            if (result.Location != null) Response.AddHeader("Location", result.Location);
            return Content(result.Json, "application/json");
        }
    }
}
