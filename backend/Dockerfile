FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY go.mod ./
COPY go.sum* ./
RUN go mod download

COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o geonote ./cmd/server

FROM alpine:3.20

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /build/geonote .
COPY --from=builder /build/migrations ./migrations

EXPOSE 8080

CMD ["./geonote"]
