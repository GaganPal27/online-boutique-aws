# Define a default value so it's not empty if the builder fails to provide it
ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM node:20.10.0-alpine@sha256:b88333c42c23fbd91596ebd7fd10de239cedab9617de04142dde7315e3bc0afa AS builder

# Some packages require additional deps for post-install scripts
RUN apk add --update --no-cache \
    python3 \
    make \
    g++

WORKDIR /usr/src/app

# 1. Copy package files from the subfolder
COPY src/currencyservice/package*.json ./

RUN npm install --only=production

FROM alpine:3.19@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

RUN apk add --no-cache nodejs

WORKDIR /usr/src/app

# 2. Copy node_modules from the builder stage
COPY --from=builder /usr/src/app/node_modules ./node_modules

# 3. Copy the application code from the subfolder
COPY src/currencyservice/ .

# 4. Copy protos (Currency service needs these for gRPC conversion logic)
COPY protos/ /usr/src/app/protos/

EXPOSE 7000

ENTRYPOINT [ "node", "server.js" ]
