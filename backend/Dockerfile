FROM golang:1.23-alpine AS builder
WORKDIR /app
RUN go install github.com/a-h/templ/cmd/templ@latest
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN templ generate ./dashboard/.klein/hotreload/... && \
	templ generate ./dashboard/views/... && \
	mkdir -p dashboard/.klein/views && \
	for f in dashboard/views/*_templ.go; do \
		base=$$(basename "$$f" _templ.go); \
		cp "$$f" "dashboard/.klein/views/$$base.templ.go"; \
	done && \
	rm -f dashboard/views/*_templ.go
RUN CGO_ENABLED=0 go build -o /api ./cmd/api

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=builder /api .
COPY migrations ./migrations
EXPOSE 8080
ENV API_ADDR=:8080
CMD ["./api"]
