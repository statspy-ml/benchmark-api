# Build stage
FROM golang:1.25.4-alpine AS builder

WORKDIR /app

# Instala dependências de build
RUN apk add --no-cache git

# Copia go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copia o código fonte
COPY main.go .

# Build do binário
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Runtime stage
FROM alpine:latest

# Instala wget para healthcheck
RUN apk --no-cache add ca-certificates wget

WORKDIR /root/

# Copia o binário do stage de build
COPY --from=builder /app/main .

# Expõe a porta
EXPOSE 8000

# Comando para rodar a aplicação
CMD ["./main"]
