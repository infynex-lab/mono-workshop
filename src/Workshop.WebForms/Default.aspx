<%@ Page Title="Home" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="Workshop.WebForms.HomePage" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h2>Runtime info</h2>
    <table>
        <tr><th>Runtime</th><td><asp:Label ID="lblRuntime" runat="server" /></td></tr>
        <tr><th>OS</th><td><asp:Label ID="lblOs" runat="server" /></td></tr>
        <tr><th>Host</th><td><asp:Label ID="lblHost" runat="server" /></td></tr>
        <tr><th>Newtonsoft.Json (NuGet)</th><td><asp:Label ID="lblNewtonsoft" runat="server" /></td></tr>
        <tr><th>Server time</th><td><asp:Label ID="lblTime" runat="server" /></td></tr>
    </table>

    <h2>Postback + ViewState</h2>
    <asp:TextBox ID="txtName" runat="server" Text="Workshop" />
    <asp:Button ID="btnGreet" runat="server" Text="Greet" OnClick="btnGreet_Click" />
    <p><strong><asp:Label ID="lblGreeting" runat="server" /></strong></p>
    <p><asp:Label ID="lblCounter" runat="server" /></p>
</asp:Content>
