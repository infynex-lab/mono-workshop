using System.Web.Mvc;
using Workshop.Core.Api;

namespace Workshop.Mvc.Controllers
{
    /// <summary>GET api/health</summary>
    public class HealthApiController : Controller
    {
        public ActionResult Index()
        {
            var result = ProductsApi.Health("mvc");
            Response.StatusCode = result.StatusCode;
            return Content(result.Json, "application/json");
        }
    }
}
