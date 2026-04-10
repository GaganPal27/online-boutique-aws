# Copyright 2021 Google LLC
# Licensed under the Apache License, Version 2.0

ARG BUILDPLATFORM=linux/amd64

# CHANGED: Updated from 1.24 to 1.25
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src

# 1. Restore dependencies
COPY go.mod go.sum ./
RUN go mod download

# 2. Copy the service source code
COPY . .

# 3. Build the binary
ARG SKAFFOLD_GO_GCFLAGS
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -ldflags="-s -w" -gcflags="${SKAFFOLD_GO_GCFLAGS}" -o /checkoutservice .

# --- Final Stage ---
FROM gcr.io/distroless/static:latest

WORKDIR /src

# 4. Copy the binary from the builder
COPY --from=builder /checkoutservice /src/checkoutservice

ENV GOTRACEBACK=single

EXPOSE 5050
ENTRYPOINT ["/src/checkoutservice"]
