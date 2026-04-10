# Copyright 2020 Google LLC
# Licensed under the Apache License, Version 2.0

ARG BUILDPLATFORM=linux/amd64

# Using Go 1.24 as requested
FROM --platform=$BUILDPLATFORM golang:1.24-alpine@sha256:2389ebfa5b7f43eeafbd6be0c3700cc46690ef842ad962f6c5bd6be49ed82039 AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src

# 1. Copy go.mod and go.sum from the specific service directory
COPY src/productcatalogservice/go.mod src/productcatalogservice/go.sum ./
RUN go mod download

# 2. Copy the rest of the service source code
COPY src/productcatalogservice/ .

# Skaffold passes in debug-oriented compiler flags
ARG SKAFFOLD_GO_GCFLAGS
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build \
    -ldflags="-s -w" \
    -gcflags="${SKAFFOLD_GO_GCFLAGS}" \
    -o /productcatalogservice .

# Final Stage
FROM gcr.io/distroless/static:latest

WORKDIR /src

# 3. Copy the binary from the builder stage
COPY --from=builder /productcatalogservice ./server

# 4. Copy the JSON file explicitly using the full path from the build context
COPY src/productcatalogservice/products.json .

# Definition of this variable is used by 'skaffold debug' to identify a golang binary.
ENV GOTRACEBACK=single

EXPOSE 3550
ENTRYPOINT ["/src/server"]
