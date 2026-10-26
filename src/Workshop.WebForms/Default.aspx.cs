using System;
using Workshop.Core;

namespace Workshop.WebForms
{
    public partial class HomePage : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            lblRuntime.Text = Server.HtmlEncode(RuntimeInfo.Describe());
            lblOs.Text = Server.HtmlEncode(Environment.OSVersion.ToString());
            lblHost.Text = Server.HtmlEncode(Environment.MachineName);
            lblNewtonsoft.Text = Server.HtmlEncode(RuntimeInfo.NewtonsoftVersion());
            lblTime.Text = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        }

        protected void btnGreet_Click(object sender, EventArgs e)
        {
            // ViewState demo: the counter travels inside the hidden __VIEWSTATE field
            var count = (ViewState["clicks"] as int?) ?? 0;
            count++;
            ViewState["clicks"] = count;

            lblGreeting.Text = "Hello, " + Server.HtmlEncode(txtName.Text) + "!";
            lblCounter.Text = "Button clicked " + count + " time(s) in this page instance.";
        }
    }
}
