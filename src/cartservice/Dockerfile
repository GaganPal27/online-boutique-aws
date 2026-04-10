# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble@sha256:88942b089c894f2963167f13019803f2df7752697a22401f7c13204780512595 AS builder
WORKDIR /app

# 1. Copy the project file and restore dependencies
# Note the path starts from the repo root
COPY src/cartservice/src/cartservice.csproj .
RUN dotnet restore cartservice.csproj

# 2. Copy the rest of the source code and the protos
COPY src/cartservice/src/ .
COPY protos/ /protos/

# 3. Publish the application
RUN dotnet publish cartservice.csproj \
    -p:PublishSingleFile=true \
    --configuration Release \
    --runtime linux-musl-x64 \
    --self-contained true \
    -p:PublishTrimmed=true \
    -p:TrimMode=full \
    -o /cartservice

# Stage 2: Final
FROM mcr.microsoft.com/dotnet/runtime-deps:9.0-noble-chiseled@sha256:1a815a519808a94662d50694e9f7532df9f357591e6f338f0d87a7183e979061
WORKDIR /app

# 4. Copy the published app from the builder
COPY --from=builder /cartservice .

EXPOSE 7070
ENV DOTNET_EnableDiagnostics=0 \
    ASPNETCORE_HTTP_PORTS=7070
USER 1000
ENTRYPOINT ["/app/cartservice"]
