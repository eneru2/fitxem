package hotreload

import (
	"net/http"
	"os"
	"sync"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(*http.Request) bool { return true },
}

// Hub tracks live reload clients.
type Hub struct {
	mu      sync.Mutex
	clients map[*websocket.Conn]struct{}
}

// Default is the package-level hub used by Mount.
var Default = NewHub()

func NewHub() *Hub {
	return &Hub{clients: make(map[*websocket.Conn]struct{})}
}

func DevEnabled() bool {
	return os.Getenv("KLEIN_DEV") != ""
}

func (h *Hub) add(conn *websocket.Conn) {
	h.mu.Lock()
	h.clients[conn] = struct{}{}
	h.mu.Unlock()
}

func (h *Hub) remove(conn *websocket.Conn) {
	h.mu.Lock()
	delete(h.clients, conn)
	h.mu.Unlock()
}

func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	h.add(conn)

	go func() {
		defer func() {
			h.remove(conn)
			conn.Close()
		}()

		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				return
			}
		}
	}()
}

func (h *Hub) ServeHealth(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

// Notify tells connected browsers to reload immediately.
func (h *Hub) Notify() {
	h.mu.Lock()
	defer h.mu.Unlock()

	for conn := range h.clients {
		if err := conn.WriteMessage(websocket.TextMessage, []byte("reload")); err != nil {
			delete(h.clients, conn)
			conn.Close()
		}
	}
}

// Mount registers dev-only hot reload routes on mux.
func Mount(mux *http.ServeMux) {
	if !DevEnabled() {
		return
	}
	mux.HandleFunc("GET /ws", Default.ServeWS)
	mux.HandleFunc("GET /health", Default.ServeHealth)
}
