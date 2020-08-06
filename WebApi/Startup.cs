using System;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace WebApi
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
                using var client = new System.Net.Http.HttpClient();
                var listenerUrl = string.Empty;
                try
                {
                    listenerUrl = Environment.GetEnvironmentVariable("LISTENER_URL") ?? "http://listenerservice:8888/";
                    client.BaseAddress = new Uri(listenerUrl);
                    var listenerResponse = await client.GetStringAsync("").ConfigureAwait(false);
                    await context.Response.WriteAsync($"Response from the API is: {listenerResponse}.").ConfigureAwait(false);
                }
                catch(Exception ex)
                {
                    await context.Response.WriteAsync($"Did not get response from the listener when calling URL \"{listenerUrl}\". Exception: {ex}.").ConfigureAwait(false);
                }
            }));
        }
    }
}
