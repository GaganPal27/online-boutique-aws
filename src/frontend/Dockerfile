ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM golang:1.26.1-alpine@sha256:2389ebfa5b7f43eeafbd6be0c3700cc46690ef842ad962f6c5bd6be49ed82039 AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64
WORKDIR /src

# 1. Restore dependencies from the correct subfolder
COPY src/frontend/go.mod src/frontend/go.sum ./
RUN go mod download

# 2. Copy the rest of the source code (required for the build)
COPY src/frontend/ . 
# 3. Copy protos if needed (this service uses them)
COPY protos/ ./protos/

# 4. Build the binary
ARG SKAFFOLD_GO_GCFLAGS
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -ldflags="-s -w" -gcflags="${SKAFFOLD_GO_GCFLAGS}" -o /go/bin/frontend .

# --- Final Stage ---
FROM gcr.io/distroless/static:latest
WORKDIR /src

# 5. Copy the compiled binary from the builder stage
COPY --from=builder /go/bin/frontend /src/server

# 6. CRITICAL FIX: Update these paths to include src/frontend/
# Because the 'context' is the repo root, we must point to the subfolder
COPY src/frontend/templates ./templates
COPY src/frontend/static ./static

ENV GOTRACEBACK=single
EXPOSE 8080
ENTRYPOINT ["/src/server"]
