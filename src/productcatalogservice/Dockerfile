ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM golang:1.26.1-alpine@sha256:2389ebfa5b7f43eeafbd6be0c3700cc46690ef842ad962f6c5bd6be49ed82039 AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src

# 1. Copy go.mod and go.sum from the subfolder
COPY src/productcatalogservice/go.mod src/productcatalogservice/go.sum ./
RUN go mod download

# 2. Copy the service source code and the protos
COPY src/productcatalogservice/ .
COPY protos/ ./protos/

# 3. Build the binary
ARG SKAFFOLD_GO_GCFLAGS
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -ldflags="-s -w" -gcflags="${SKAFFOLD_GO_GCFLAGS}" -o /productcatalogservice .

# --- Final Stage ---
FROM gcr.io/distroless/static:latest

WORKDIR /src

# 4. Copy the binary from the builder
COPY --from=builder /productcatalogservice ./server

# 5. CRITICAL: Copy the products.json data file from the subfolder
COPY src/productcatalogservice/products.json .

ENV GOTRACEBACK=single
EXPOSE 3550
ENTRYPOINT ["/src/server"]
