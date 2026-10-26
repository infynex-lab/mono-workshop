<%@ Page Title="Products" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Products.aspx.cs" Inherits="Workshop.WebForms.ProductsPage" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h2>Products</h2>
    <asp:GridView ID="gridProducts" runat="server" AutoGenerateColumns="false" GridLines="None">
        <Columns>
            <asp:BoundField DataField="Id" HeaderText="ID" />
            <asp:BoundField DataField="Name" HeaderText="Name" />
            <asp:BoundField DataField="Price" HeaderText="Price" DataFormatString="{0:0.00}" HtmlEncode="false" />
        </Columns>
    </asp:GridView>

    <h2>Add product</h2>
    Name: <asp:TextBox ID="txtName" runat="server" />
    Price: <asp:TextBox ID="txtPrice" runat="server" Width="80" />
    <asp:Button ID="btnAdd" runat="server" Text="Add" OnClick="btnAdd_Click" />
    <p><asp:Label ID="lblMessage" runat="server" /></p>
</asp:Content>
