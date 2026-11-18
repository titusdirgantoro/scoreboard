// Package logx builds the structured logger used by every program.
package logx

import (
	"io"
	"log/slog"
	"strings"
)

// New returns a JSON logger in prod and a text logger for local runs.
func New(w io.Writer, env, level string) *slog.Logger {
	var lv slog.Level
	switch strings.ToLower(level) {
	case "debug":
		lv = slog.LevelDebug
	case "warn":
		lv = slog.LevelWarn
	case "error":
		lv = slog.LevelError
	default:
		lv = slog.LevelInfo
	}
	opts := &slog.HandlerOptions{Level: lv}
	if env != "local" {
		return slog.New(slog.NewJSONHandler(w, opts))
	}
	return slog.New(slog.NewTextHandler(w, opts))
}

// MaskPhone hides the middle digits of a phone number for logs: +6281234567890 → +62812****7890.
func MaskPhone(p string) string {
	if len(p) <= 8 {
		return "****"
	}
	return p[:6] + "****" + p[len(p)-4:]
}
