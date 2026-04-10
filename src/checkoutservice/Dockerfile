# Copyright 2021 Google LLC
# Licensed under the Apache License, Version 2.0

ARG BUILDPLATFORM=linux/amd64

# Using Go 1.25 as requested
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src

# 1. Restore dependencies from the specific subfolder
# This fixes the "/go.sum not found" error
COPY src/checkoutservice/go.mod src/checkoutservice/go.sum ./
RUN go mod download

# 2. Copy the service source code from the subfolder
COPY src/checkoutservice/ .

# 3. Build the binary
ARG SKAFFOLD_GO_GCFLAGS
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build \
    -ldflags="-s -w" \
    -gcflags="${SKAFFOLD_GO_GCFLAGS}" \
    -o /checkoutservice .

# --- Final Stage ---
FROM gcr.io/distroless/static:latest

WORKDIR /src

# 4. Copy the binary from the builder
COPY --from=builder /checkoutservice /src/checkoutservice

ENV GOTRACEBACK=single

EXPOSE 5050
ENTRYPOINT ["/src/checkoutservice"]
