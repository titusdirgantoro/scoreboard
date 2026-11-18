// Package app wires configuration, modules, and routes into one http.Handler.
// Each module registers its own routes here as tasks in docs/TASKS.md land.
package app

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"tiusapp.com/scoreboard/internal/infra/config"
	"tiusapp.com/scoreboard/internal/infra/httpx"
	"tiusapp.com/scoreboard/internal/live"
)

// Pinger checks a dependency (the database pool implements it in T-006).
type Pinger interface {
	Ping(ctx context.Context) error
}

// Deps are long-lived dependencies created by cmd/api.
type Deps struct {
	Config config.Config
	Log    *slog.Logger
	DB     Pinger // nil until T-006
	Hub    *live.Hub
}

// New returns the root handler.
func New(d Deps) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok", "version": d.Config.Version})
	})

	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if d.DB == nil {
			// TODO(T-006): wajibkan DB setelah pool pgx terpasang.
			httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok", "db": "not_configured"})
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), time.Second)
		defer cancel()
		if err := d.DB.Ping(ctx); err != nil {
			d.Log.Warn("readyz: db ping gagal", "err", err)
			httpx.WriteJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "unavailable", "db": "down"})
			return
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok", "db": "up"})
	})

	mux.HandleFunc("GET /api/v1/meta", func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{
			"name":    "scoreboard.tiusapp.com",
			"version": d.Config.Version,
			"env":     d.Config.Env,
			"time":    time.Now().UTC().Format(time.RFC3339),
		})
	})

	// Modules register here, e.g.:
	//   auth.Register(mux, authService)      // T-011
	//   event.Register(mux, eventService)    // T-020
	//   live.Register(mux, liveService, d.Hub) // T-032, T-033

	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteError(w, r, httpx.ErrNotFound)
	})
	mux.HandleFunc("/ws/", func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteError(w, r, httpx.ErrNotImplemented) // T-033
	})

	// TODO(T-024): ganti nil dengan injektor meta OG dari modul event.
	mux.Handle("/", httpx.SPA(d.Config.WebDistDir, nil))

	return httpx.Chain(mux,
		httpx.WithRequestID,
		httpx.WithRecover(d.Log),
		httpx.WithAccessLog(d.Log),
	)
}
