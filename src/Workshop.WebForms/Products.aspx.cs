using System;
using System.Globalization;
using Workshop.Core.Data;

namespace Workshop.WebForms
{
    public partial class ProductsPage : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack) BindGrid();
        }

        protected void btnAdd_Click(object sender, EventArgs e)
        {
            double price;
            if (string.IsNullOrWhiteSpace(txtName.Text) ||
                !double.TryParse(txtPrice.Text, NumberStyles.Float, CultureInfo.InvariantCulture, out price) ||
                price < 0)
            {
                lblMessage.Text = "Please enter a name and a valid price (e.g. 12.50).";
                return;
            }
            var product = ProductRepository.Add(txtName.Text.Trim(), price);
            lblMessage.Text = "Added product #" + product.Id + ".";
            txtName.Text = "";
            txtPrice.Text = "";
            BindGrid();
        }

        private void BindGrid()
        {
            gridProducts.DataSource = ProductRepository.All();
            gridProducts.DataBind();
        }
    }
}
