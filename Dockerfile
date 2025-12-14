# Stage 1: Build the binaray
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Copy module files and source code
COPY go.mod ./
COPY . .

# Build the Go app
RUN go build -o server main.go

# Stage 2: Create a minimal runtime image
FROM alpine:latest
WORKDIR /root

# Copy the binaray from the builder stage
COPY --from=builder /app/server .

# Expose the port
EXPOSE 8080

# Run the binary
CMD [ "./server" ]
