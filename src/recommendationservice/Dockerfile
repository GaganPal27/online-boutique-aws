# Copyright 2021 Google LLC
# Licensed under the Apache License, Version 2.0

# Use the default build platform if not provided
ARG BUILDPLATFORM=linux/amd64

# Use Python 3.12 (Stable) for better Alpine compatibility
FROM --platform=$BUILDPLATFORM python:3.12-alpine AS base

FROM base AS builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apk update \
    && apk add --no-cache g++ linux-headers \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# 1. FIXED: Point to the specific service folder in the root context
COPY src/recommendationservice/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apk update \
    && apk add --no-cache libstdc++ \
    && rm -rf /var/cache/apk/*

WORKDIR /recommendationservice

# 2. Grab packages using prefix for reliability
COPY --from=builder /install /usr/local

# 3. FIXED: Add the application code from the specific service folder
COPY src/recommendationservice/ .

# 4. NOTE: Protos are included in the copy above if they are in the service folder.
# If they are in a global root folder, you would need:
# COPY protos/ ./protos/

# Set listen port
ENV PORT="8080"
EXPOSE 8080

ENTRYPOINT ["python", "recommendation_server.py"]
