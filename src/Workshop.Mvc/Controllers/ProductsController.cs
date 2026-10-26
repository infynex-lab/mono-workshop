using System.Globalization;
using System.Web.Mvc;
using Workshop.Core.Data;

namespace Workshop.Mvc.Controllers
{
    public class ProductsController : Controller
    {
        public ActionResult Index()
        {
            ViewBag.Message = TempData["Message"];
            return View(ProductRepository.All());
        }

        [HttpPost]
        public ActionResult Create(string name, string price)
        {
            double value;
            if (string.IsNullOrWhiteSpace(name) ||
                !double.TryParse(price, NumberStyles.Float, CultureInfo.InvariantCulture, out value) ||
                value < 0)
            {
                TempData["Message"] = "Please enter a name and a valid price (e.g. 12.50).";
            }
            else
            {
                var product = ProductRepository.Add(name.Trim(), value);
                TempData["Message"] = "Added product #" + product.Id + ".";
            }
            return RedirectToAction("Index");
        }
    }
}
