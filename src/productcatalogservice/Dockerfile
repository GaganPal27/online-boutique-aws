# Copyright 2020 Google LLC
# Licensed under the Apache License, Version 2.0

# Define a default value so it's not empty if the builder fails to provide it
ARG BUILDPLATFORM=linux/amd64

# GOLANG VERSION NOTE: Changed to 1.24 as 1.26 is not yet released
FROM --platform=$BUILDPLATFORM golang:1.24-alpine@sha256:2389ebfa5b7f43eeafbd6be0c3700cc46690ef842ad962f6c5bd6be49ed82039 AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src

# 1. Copy go.mod and go.sum first to leverage Docker cache
COPY go.mod go.sum ./
RUN go mod download

# 2. Copy the rest of the source code
# This will include products.json if it is in this folder
COPY . .

# Skaffold passes in debug-oriented compiler flags
ARG SKAFFOLD_GO_GCFLAGS
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -ldflags="-s -w" -gcflags="${SKAFFOLD_GO_GCFLAGS}" -o /productcatalogservice .

# Final Stage
FROM gcr.io/distroless/static:latest

WORKDIR /src

# 3. Copy the binary from the builder stage
COPY --from=builder /productcatalogservice ./server

# 4. Copy the JSON file explicitly from the CURRENT directory
# This matches your setup where the file is next to the Dockerfile
COPY products.json .

# Definition of this variable is used by 'skaffold debug' to identify a golang binary.
ENV GOTRACEBACK=single

EXPOSE 3550
ENTRYPOINT ["/src/server"]
