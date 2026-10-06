FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY back/Bagage.Api/Bagage.Api.csproj back/Bagage.Api/
RUN dotnet restore back/Bagage.Api/Bagage.Api.csproj
COPY back/Bagage.Api/ back/Bagage.Api/
RUN dotnet publish back/Bagage.Api/Bagage.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app .
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "Bagage.Api.dll"]
