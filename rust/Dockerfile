# Build stage
FROM rust:1.91.1-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache musl-dev pkgconfig openssl-dev openssl-libs-static

# Copy manifests
COPY Cargo.toml Cargo.lock* ./

# Copy source
COPY src ./src

# Build for release
RUN cargo build --release

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates wget libgcc

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/target/release/benchmark-rust .

EXPOSE 8000

CMD ["./benchmark-rust"]
