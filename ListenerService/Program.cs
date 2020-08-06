using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace ListenerService
{
    class Program
    {
        public static async Task Main(string[] args)
        {
            var host = CreateHostBuilder(args).Build();
            var serverAddresses = host.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>();
            foreach(var serverAddress in serverAddresses.Addresses)
            {
                Trace.WriteLine(serverAddress);
            }

            await host.RunAsync().ConfigureAwait(false);
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    var port = Environment.GetEnvironmentVariable("WEBSITES_PORT") ?? "9999";
                    if(!string.IsNullOrWhiteSpace(port))
                    {
                        _ = webBuilder.UseUrls($"http://+:{port}");
                    }

                    _ = webBuilder.UseStartup<Startup>();
                });
    }
}
