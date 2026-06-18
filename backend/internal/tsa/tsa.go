package tsa

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"
)

type Client interface {
	Timestamp(ctx context.Context, data []byte) ([]byte, error)
}

type Mock struct{}

func (Mock) Timestamp(_ context.Context, data []byte) ([]byte, error) {
	h := sha256.Sum256(append(data, []byte("mock-tsa")...))
	token := fmt.Sprintf("MOCK-TSA:%s:%s", time.Now().UTC().Format(time.RFC3339Nano), hex.EncodeToString(h[:]))
	return []byte(token), nil
}

func NewClient(url string) Client {
	if url == "" || url == "mock" {
		return Mock{}
	}
	return &HTTP{URL: url}
}

type HTTP struct {
	URL string
}

func (t *HTTP) Timestamp(ctx context.Context, data []byte) ([]byte, error) {
	h := sha256.Sum256(data)
	token := fmt.Sprintf("HTTP-TSA:%s:%s", t.URL, hex.EncodeToString(h[:]))
	return []byte(token), nil
}
