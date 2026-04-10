# Copyright 2021 Google LLC
# Licensed under the Apache License, Version 2.0

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

# 1. FIXED: Copy relative to the context root
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apk update \
    && apk add --no-cache libstdc++ \
    && rm -rf /var/cache/apk/*

WORKDIR /recommendationservice

# 2. FIXED: Grab packages using prefix for reliability
COPY --from=builder /install /usr/local

# 3. FIXED: Add the application code from current context
COPY . .

# 4. NOTE: Protos must be inside src/recommendationservice/ for Docker to see them
# COPY protos/ ./protos/

# Set listen port
ENV PORT="8080"
EXPOSE 8080

ENTRYPOINT ["python", "recommendation_server.py"]
