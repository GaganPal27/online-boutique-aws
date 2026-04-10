ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM golang:1.26.1-alpine@sha256:2389ebfa5b7f43eeafbd6be0c3700cc46690ef842ad962f6c5bd6be49ed82039 AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64
WORKDIR /src

# 1. Restore dependencies from the subfolder
COPY src/checkoutservice/go.mod src/checkoutservice/go.sum ./
RUN go mod download

# 2. Copy the service source code and the protos
COPY src/checkoutservice/ .
COPY protos/ ./protos/

# 3. Build the binary
ARG SKAFFOLD_GO_GCFLAGS
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -ldflags="-s -w" -gcflags="${SKAFFOLD_GO_GCFLAGS}" -o /checkoutservice .

# --- Final Stage ---
FROM gcr.io/distroless/static:latest

WORKDIR /src

# 4. Copy the binary from the builder
COPY --from=builder /checkoutservice /src/checkoutservice

# Definition of this variable is used by 'skaffold debug' to identify a golang binary.
ENV GOTRACEBACK=single

EXPOSE 5050
ENTRYPOINT ["/src/checkoutservice"]
