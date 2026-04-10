# Copyright 2021 Google LLC
# Licensed under the Apache License, Version 2.0

ARG BUILDPLATFORM=linux/amd64

# Using Python 3.12 for better stability with gRPC on Alpine
FROM --platform=$BUILDPLATFORM python:3.12-alpine AS base

FROM base AS builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apk update \
    && apk add --no-cache g++ linux-headers \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# 1. Copy requirements from the current directory (the service folder)
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV ENABLE_PROFILER=1

RUN apk update \
    && apk add --no-cache libstdc++ \
    && rm -rf /var/cache/apk/*

WORKDIR /email_server

# 2. Grab packages from builder stage
COPY --from=builder /install /usr/local

# 3. Add the application code from the current directory
COPY . .

# 4. Ensure protos are accessible if they were moved into this folder
# COPY protos/ ./protos/

EXPOSE 8080
ENTRYPOINT [ "python", "email_server.py" ]
