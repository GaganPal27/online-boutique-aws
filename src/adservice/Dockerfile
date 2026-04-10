# Builder Stage
FROM eclipse-temurin:21-jdk-noble AS builder
WORKDIR /app

# 1. Copy Gradle wrapper and config
COPY src/adservice/build.gradle src/adservice/gradlew ./
COPY src/adservice/gradle gradle

# 2. IMPORTANT: Copy the SHARED protos folder
COPY protos/ /app/protos/

# 3. Copy the rest of the source code
COPY src/adservice/ .

# 4. FIX PERMISSIONS & LINE ENDINGS
# We do this after all copies to ensure the 'x' bit stays set
# 'sed' removes Windows line endings that break scripts on Linux
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew

# 5. Build the application
RUN ./gradlew installDist

# Final Stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/install/hipstershop /app

EXPOSE 9555
ENTRYPOINT ["/app/bin/AdService"]
