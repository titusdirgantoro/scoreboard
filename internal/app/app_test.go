package app

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"tiusapp.com/scoreboard/internal/infra/config"
	"tiusapp.com/scoreboard/internal/live"
)

type fakeDB struct{ err error }

func (f fakeDB) Ping(context.Context) error { return f.err }

func newTestApp(db Pinger) http.Handler {
	return New(Deps{
		Config: config.Config{Env: "local", Version: "test", WebDistDir: "does-not-exist"},
		Log:    slog.New(slog.NewTextHandler(io.Discard, nil)),
		DB:     db,
		Hub:    live.NewHub(8),
	})
}

func get(h http.Handler, path string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestRoutes(t *testing.T) {
	cases := []struct {
		name   string
		db     Pinger
		path   string
		status int
	}{
		{"health", nil, "/healthz", 200},
		{"ready tanpa db", nil, "/readyz", 200},
		{"ready db hidup", fakeDB{}, "/readyz", 200},
		{"ready db mati", fakeDB{err: errors.New("down")}, "/readyz", 503},
		{"meta", nil, "/api/v1/meta", 200},
		{"api tidak dikenal", nil, "/api/v1/tidak-ada", 404},
		{"ws belum ada", nil, "/ws/live", 501},
		{"spa placeholder", nil, "/e/piala-jumat-malam-2026", 200},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := get(newTestApp(tc.db), tc.path)
			if rec.Code != tc.status {
				t.Fatalf("%s: status %d, mau %d (%s)", tc.path, rec.Code, tc.status, rec.Body.String())
			}
			if rec.Header().Get("X-Request-ID") == "" {
				t.Fatal("X-Request-ID tidak ada")
			}
		})
	}
}
