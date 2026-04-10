# Define a default value so it's not empty if the builder fails to provide it
ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM golang:1.26.1-alpine@sha256:2389ebfa5b7f43eeafbd6be0c3700cc46690ef842ad962f6c5bd6be49ed82039 AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64
WORKDIR /src

# 1. Restore dependencies from the correct subfolder
COPY src/shippingservice/go.mod src/shippingservice/go.sum ./
RUN go mod download

# 2. Copy the service source code and the protos
COPY src/shippingservice/ .
COPY protos/ ./protos/

# 3. Build the binary
ARG SKAFFOLD_GO_GCFLAGS
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -ldflags="-s -w" -gcflags="${SKAFFOLD_GO_GCFLAGS}" -o /go/bin/shippingservice .

# --- Final Stage ---
FROM gcr.io/distroless/static:latest

WORKDIR /src
# 4. Copy the compiled binary from the builder stage
COPY --from=builder /go/bin/shippingservice /src/shippingservice

ENV APP_PORT=50051
ENV GOTRACEBACK=single

EXPOSE 50051
ENTRYPOINT ["/src/shippingservice"]
