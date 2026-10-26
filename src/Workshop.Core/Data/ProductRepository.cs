using System.Collections.Generic;
using System.Linq;
using Workshop.Core.Models;

namespace Workshop.Core.Data
{
    /// <summary>In-memory store shared by pages, controllers and API (no database needed for the workshop).</summary>
    public static class ProductRepository
    {
        private static readonly object Sync = new object();
        private static readonly List<Product> Items = new List<Product>
        {
            new Product { Id = 1, Name = "Keyboard", Price = 49.90 },
            new Product { Id = 2, Name = "Monitor",  Price = 189.00 },
            new Product { Id = 3, Name = "Webcam",   Price = 59.50 }
        };

        public static List<Product> All()
        {
            lock (Sync)
            {
                return Items.Select(p => new Product { Id = p.Id, Name = p.Name, Price = p.Price }).ToList();
            }
        }

        public static Product Find(int id)
        {
            lock (Sync) { return Items.FirstOrDefault(p => p.Id == id); }
        }

        public static Product Add(string name, double price)
        {
            lock (Sync)
            {
                var id = Items.Count == 0 ? 1 : Items.Max(p => p.Id) + 1;
                var product = new Product { Id = id, Name = name, Price = price };
                Items.Add(product);
                return product;
            }
        }
    }
}
