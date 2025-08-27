# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./
COPY ../module/go.mod ../module/go.sum ../module/

# Download dependencies
RUN go mod download

# Copy source code
COPY . .
COPY ../module ../module

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o scheduler cmd/scheduler/main.go

# Final stage
FROM alpine:latest

# Install ca-certificates
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary
COPY --from=builder /app/scheduler .

# Run the binary
CMD ["./scheduler"]