using System;
using System.Reflection;
using Newtonsoft.Json;

namespace Workshop.Core
{
    public static class RuntimeInfo
    {
        /// <summary>Mono (Linux) or the real .NET Framework (Windows/IIS)?</summary>
        public static string Describe()
        {
            var mono = Type.GetType("Mono.Runtime");
            if (mono != null)
            {
                var m = mono.GetMethod("GetDisplayName", BindingFlags.NonPublic | BindingFlags.Static);
                return m != null ? "Mono " + m.Invoke(null, null) : "Mono";
            }
            return ".NET Framework " + Environment.Version;
        }

        /// <summary>Proves the NuGet package really was restored, shipped in /bin and loaded at runtime.</summary>
        public static string NewtonsoftVersion()
        {
            return typeof(JsonConvert).Assembly.GetName().Version.ToString();
        }
    }
}
