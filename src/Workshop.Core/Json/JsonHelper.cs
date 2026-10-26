using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace Workshop.Core.Json
{
    /// <summary>Thin wrapper over Newtonsoft.Json: the sample "NuGet dependency" of the workshop.</summary>
    public static class JsonHelper
    {
        private static readonly JsonSerializerSettings Settings = new JsonSerializerSettings
        {
            ContractResolver = new CamelCasePropertyNamesContractResolver()
        };

        public static string Serialize(object value)
        {
            return JsonConvert.SerializeObject(value, Settings);
        }

        public static T Deserialize<T>(string json) where T : class
        {
            if (string.IsNullOrWhiteSpace(json)) return null;
            try { return JsonConvert.DeserializeObject<T>(json, Settings); }
            catch (JsonException) { return null; }
        }
    }
}
