FROM ghcr.io/cirruslabs/flutter:stable AS cliente
WORKDIR /src/cliente
COPY cliente/pubspec.yaml cliente/pubspec.lock ./
RUN flutter pub get
COPY cliente/ ./
RUN flutter build web --release

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS compilacao
WORKDIR /src
COPY servidor/TocaEssaApp.Api/TocaEssaApp.Api.csproj servidor/TocaEssaApp.Api/
RUN dotnet restore servidor/TocaEssaApp.Api/TocaEssaApp.Api.csproj
COPY servidor/TocaEssaApp.Api/ servidor/TocaEssaApp.Api/
RUN dotnet publish servidor/TocaEssaApp.Api/TocaEssaApp.Api.csproj \
    --configuration Release --no-restore --output /app/publicar
COPY --from=cliente /src/cliente/build/web /app/publicar/wwwroot

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=compilacao /app/publicar ./
ENV ASPNETCORE_HTTP_PORTS=10000
EXPOSE 10000
ENTRYPOINT ["dotnet", "TocaEssaApp.Api.dll"]
