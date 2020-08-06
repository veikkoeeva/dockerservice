using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;

namespace ListenerService
{
    public class Startup
    {
        public void ConfigureServices(IServiceCollection services)
        {
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if(env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseRouting();
            app.UseEndpoints(endpoints => endpoints.MapGet("/", async context =>
            {
                try
                {
                    var conn = new Microsoft.Data.SqlClient.SqlConnection("Server=tcp:testsqlserver123.database.windows.net,1433;Database=testdatabase123")
                    {
                        AccessToken = await new Microsoft.Azure.Services.AppAuthentication.AzureServiceTokenProvider().GetAccessTokenAsync("https://database.windows.net/").ConfigureAwait(false)
                    };

                    await context.Response.WriteAsync($"Listener tells: Hello, World!").ConfigureAwait(false);
                }
                catch(Exception ex)
                {
                    await context.Response.WriteAsync($"Listener tells: Hello, World with {ex}").ConfigureAwait(false);
                }
            }));
        }
    }
}
