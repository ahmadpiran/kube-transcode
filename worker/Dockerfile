# Stage 1: Build
FROM golang:1.25-alpine AS builder
WORKDIR /app

# We need the go.mod from the root (parent context)
COPY go.mod go.sum ./
RUN go mod download

# Copy the worker source code
COPY worker/ ./worker/

# Build the worker binary
RUN go build -o worker-bin ./worker/main.go

# Stage 2: Runtime
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/worker-bin .
CMD ["./worker-bin"]