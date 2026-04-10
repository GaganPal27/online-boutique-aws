# Builder Stage
FROM eclipse-temurin:21-jdk-noble AS builder
WORKDIR /app

# 1. Copy Gradle wrapper and config
COPY src/adservice/build.gradle src/adservice/gradlew ./
COPY src/adservice/gradle gradle

# 2. Grant execution rights and download dependencies
RUN chmod +x gradlew
RUN ./gradlew downloadRepos

# 3. IMPORTANT: Copy the SHARED protos folder from the root
# AdService needs this to generate gRPC code!
COPY protos/ /app/protos/

# 4. Copy the service source code
COPY src/adservice/ .

# 5. Build the application
# If this fails, it usually tells you exactly which file is missing
RUN ./gradlew installDist

# Final Stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/install/hipstershop /app

EXPOSE 9555
ENTRYPOINT ["/app/bin/AdService"]
