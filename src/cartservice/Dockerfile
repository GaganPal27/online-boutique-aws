# STAGE 1: Build
FROM mcr.microsoft.com/dotnet/sdk:10.0-noble AS builder
ARG TARGETARCH=amd64
WORKDIR /app

# 1. Copy project file and restore
COPY src/cartservice/cartservice.csproj .
RUN dotnet restore cartservice.csproj -a $TARGETARCH

# 2. Copy EVERYTHING from the service folder 
# This includes cartstore/, services/, and protos/
COPY src/cartservice/ .

# 3. Publish the application
# We use the exclude flag to keep the compiler away from the 'tests' folder
RUN dotnet publish cartservice.csproj \
    -p:PublishSingleFile=true \
    -a $TARGETARCH \
    --self-contained true \
    -p:PublishTrimmed=true \
    -p:TrimMode=full \
    -c release \
    -o /cartservice_out \
    -p:DefaultItemExcludes="tests/**"

# STAGE 2: Final Runtime
FROM mcr.microsoft.com/dotnet/runtime-deps:10.0-noble-chiseled
WORKDIR /app
COPY --from=builder /cartservice_out .

ENTRYPOINT ["./cartservice"]
