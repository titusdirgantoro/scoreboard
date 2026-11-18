// Package httpx holds HTTP helpers shared by all modules: JSON responses,
// the API error envelope, middleware, and the SPA file server.
package httpx

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"runtime/debug"
	"time"
)

// Error is a domain error with a stable API code (see docs/ARCHITECTURE.md §13).
type Error struct {
	Status  int               `json:"-"`
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Fields  map[string]string `json:"fields,omitempty"`
	Extra   map[string]any    `json:"-"`
}

func (e *Error) Error() string { return e.Code + ": " + e.Message }

// Common errors. Modules may create their own with NewError.
var (
	ErrNotFound       = &Error{Status: http.StatusNotFound, Code: "not_found", Message: "Data tidak ditemukan."}
	ErrForbidden      = &Error{Status: http.StatusForbidden, Code: "forbidden", Message: "Kamu tidak punya akses untuk ini."}
	ErrUnauthorized   = &Error{Status: http.StatusUnauthorized, Code: "unauthorized", Message: "Silakan masuk dulu."}
	ErrNotImplemented = &Error{Status: http.StatusNotImplemented, Code: "not_implemented", Message: "Fitur ini belum dibuat."}
)

// NewError builds an *Error.
func NewError(status int, code, message string) *Error {
	return &Error{Status: status, Code: code, Message: message}
}

// WriteJSON writes v as JSON with the given status.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// WriteError maps err to the API error envelope. Unknown errors become 500
// without leaking details to the client.
func WriteError(w http.ResponseWriter, r *http.Request, err error) {
	var e *Error
	if !errors.As(err, &e) {
		slog.ErrorContext(r.Context(), "unhandled error", "err", err, "request_id", RequestID(r))
		e = &Error{Status: http.StatusInternalServerError, Code: "internal", Message: "Terjadi kesalahan di server."}
	}
	body := map[string]any{"code": e.Code, "message": e.Message}
	if len(e.Fields) > 0 {
		body["fields"] = e.Fields
	}
	for k, v := range e.Extra {
		body[k] = v
	}
	WriteJSON(w, e.Status, map[string]any{"error": body})
}

// ---------- middleware ----------

type ctxKey int

const requestIDKey ctxKey = 1

// RequestID returns the request id set by WithRequestID.
func RequestID(r *http.Request) string {
	if v, ok := r.Context().Value(requestIDKey).(string); ok {
		return v
	}
	return ""
}

// Chain applies middleware in order: Chain(h, a, b) == a(b(h)).
func Chain(h http.Handler, mw ...func(http.Handler) http.Handler) http.Handler {
	for i := len(mw) - 1; i >= 0; i-- {
		h = mw[i](h)
	}
	return h
}

// WithRequestID attaches an X-Request-ID (incoming or generated).
func WithRequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-ID")
		if id == "" || len(id) > 64 {
			b := make([]byte, 8)
			_, _ = rand.Read(b)
			id = hex.EncodeToString(b)
		}
		w.Header().Set("X-Request-ID", id)
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), requestIDKey, id)))
	})
}

// WithRecover turns panics into a 500 response and logs the stack.
func WithRecover(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if v := recover(); v != nil {
					if v == http.ErrAbortHandler {
						panic(v)
					}
					log.Error("panic", "value", v, "request_id", RequestID(r), "stack", string(debug.Stack()))
					WriteError(w, r, errors.New("panic"))
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

type statusRecorder struct {
	http.ResponseWriter
	status int
	bytes  int
}

func (s *statusRecorder) WriteHeader(code int) { s.status = code; s.ResponseWriter.WriteHeader(code) }
func (s *statusRecorder) Write(b []byte) (int, error) {
	if s.status == 0 {
		s.status = http.StatusOK
	}
	n, err := s.ResponseWriter.Write(b)
	s.bytes += n
	return n, err
}

// Unwrap lets http.ResponseController reach the underlying writer (needed for WebSocket hijack).
func (s *statusRecorder) Unwrap() http.ResponseWriter { return s.ResponseWriter }

// WithAccessLog logs one line per request.
func WithAccessLog(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &statusRecorder{ResponseWriter: w}
			next.ServeHTTP(rec, r)
			if r.URL.Path == "/healthz" {
				return
			}
			log.Info("http",
				"method", r.Method, "path", r.URL.Path, "status", rec.status,
				"bytes", rec.bytes, "dur_ms", time.Since(start).Milliseconds(),
				"request_id", RequestID(r))
		})
	}
}
