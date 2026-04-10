# Copyright 2021 Google LLC
# Licensed under the Apache License, Version 2.0

ARG BUILDPLATFORM=linux/amd64

# Builder Stage
FROM --platform=$BUILDPLATFORM eclipse-temurin:21-jdk-noble AS builder

WORKDIR /app

# 1. FIXED: Copy Gradle wrapper and config from the specific service subfolder
COPY src/adservice/build.gradle src/adservice/gradlew ./
COPY src/adservice/gradle gradle

# 2. Grant execution rights and download dependencies
RUN chmod +x gradlew
RUN ./gradlew downloadRepos

# 3. FIXED: Copy the rest of the source code from the service subfolder
COPY src/adservice/ .

# 4. Build the application
RUN ./gradlew installDist

# --- Final Stage ---
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# 5. Copy the built application from the builder stage
COPY --from=builder /app/build/install/hipstershop /app

EXPOSE 9555
ENTRYPOINT ["/app/bin/AdService"]
