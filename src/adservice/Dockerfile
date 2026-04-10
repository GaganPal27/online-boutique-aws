# Copyright 2021 Google LLC
# Licensed under the Apache License, Version 2.0

ARG BUILDPLATFORM=linux/amd64

# Builder Stage
FROM --platform=$BUILDPLATFORM eclipse-temurin:21-jdk-noble AS builder

WORKDIR /app

# 1. FIXED: Copy Gradle wrapper and config relative to the context root
COPY build.gradle gradlew ./
COPY gradle gradle

# 2. Grant execution rights and download dependencies
RUN chmod +x gradlew
RUN ./gradlew downloadRepos

# 3. FIXED: Copy the rest of the source code
# Note: Protos must be moved into src/adservice/ for this to work
COPY . .

# 4. Build the application
RUN ./gradlew installDist

# --- Final Stage ---
# Standardizing to a stable JRE version
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# 5. Copy the built application from the builder stage
COPY --from=builder /app/build/install/hipstershop /app

EXPOSE 9555
ENTRYPOINT ["/app/bin/AdService"]
