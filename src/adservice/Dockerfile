ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM eclipse-temurin:24.0.2_12-jdk-noble@sha256:dacac8e9a0df0d2bd24e702b4431132875c249930b70555ebd7ca285b5bee684 AS builder

WORKDIR /app

# 1. Copy Gradle wrapper and configuration from the subfolder
COPY src/adservice/build.gradle src/adservice/gradlew ./
COPY src/adservice/gradle gradle

# 2. Grant execution rights and download dependencies
RUN chmod +x gradlew
RUN ./gradlew downloadRepos

# 3. Copy the rest of the adservice source code AND the protos
COPY src/adservice/ .
COPY protos/ /app/protos/

# 4. Build the application
RUN chmod +x gradlew
RUN ./gradlew installDist

# --- Final Stage ---
FROM eclipse-temurin:25.0.2_10-jre-alpine@sha256:f10d6259d0798c1e12179b6bf3b63cea0d6843f7b09c9f9c9c422c50e44379ec

WORKDIR /app

# 5. Copy the built application from the builder stage
COPY --from=builder /app .

EXPOSE 9555
ENTRYPOINT ["/app/build/install/hipstershop/bin/AdService"]
