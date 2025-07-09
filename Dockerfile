FROM rust:latest as build

WORKDIR /app

RUN \
  DEBIAN_FRONTEND=noninteractive \
  apt-get update &&\
  apt-get -y install ca-certificates tzdata

# Copy only dependency files first for better layer caching
COPY Cargo.toml Cargo.lock ./

# Create a dummy main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies (this layer will be cached if Cargo.toml doesn't change)
RUN \
  CARGO_NET_GIT_FETCH_WITH_CLI=true \
  cargo build --release && \
  rm -rf src target/release/deps/microbin*

# Copy source code
COPY src ./src
COPY templates ./templates

# Build the actual application
RUN \
  CARGO_NET_GIT_FETCH_WITH_CLI=true \
  cargo build --release

# https://hub.docker.com/r/bitnami/minideb
FROM bitnami/minideb:latest

# microbin will be in /app
WORKDIR /app

RUN mkdir -p /usr/share/zoneinfo

# copy time zone info
COPY --from=build \
  /usr/share/zoneinfo \
  /usr/share/

COPY --from=build \
  /etc/ssl/certs/ca-certificates.crt \
  /etc/ssl/certs/ca-certificates.crt

# copy built executable
COPY --from=build \
  /app/target/release/microbin \
  /usr/bin/microbin

# Expose webport used for the webserver to the docker runtime
EXPOSE 8080

ENTRYPOINT ["microbin"]
