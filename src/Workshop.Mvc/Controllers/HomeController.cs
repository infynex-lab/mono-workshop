using System;
using System.Web.Mvc;
using Workshop.Core;

namespace Workshop.Mvc.Controllers
{
    public class HomeController : Controller
    {
        public ActionResult Index()
        {
            ViewBag.Runtime = RuntimeInfo.Describe();
            ViewBag.Os = Environment.OSVersion.ToString();
            ViewBag.Host = Environment.MachineName;
            ViewBag.Newtonsoft = RuntimeInfo.NewtonsoftVersion();
            ViewBag.Time = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            return View();
        }
    }
}
