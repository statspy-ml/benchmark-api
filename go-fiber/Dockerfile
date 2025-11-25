FROM golang:1.23-alpine AS builder

WORKDIR /app

# Instala dependências básicas
RUN apk add --no-cache git

# Copia arquivos de dependências
COPY go.mod go.sum* ./
RUN go mod download

# Copia código fonte
COPY . .

# Compila a aplicação
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Imagem final
FROM alpine:latest

RUN apk --no-cache add ca-certificates wget

WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE 8000

CMD ["./main"]
