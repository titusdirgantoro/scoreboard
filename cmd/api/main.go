// Command api serves the HTTP API, WebSocket live feed, and the web app.
package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"tiusapp.com/scoreboard/internal/app"
	"tiusapp.com/scoreboard/internal/infra/config"
	"tiusapp.com/scoreboard/internal/infra/logx"
	"tiusapp.com/scoreboard/internal/live"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "api:", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.FromEnv()
	if err != nil {
		return err
	}
	log := logx.New(os.Stdout, cfg.Env, cfg.LogLevel)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// TODO(T-006): buka pool pgx dari cfg.DatabaseURL dan isi Deps.DB.
	handler := app.New(app.Deps{Config: cfg, Log: log, Hub: live.NewHub(32)})

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second, // WebSocket memakai ResponseController untuk menghapus batas ini (T-033)
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Info("api mulai", "addr", cfg.HTTPAddr, "env", cfg.Env, "version", cfg.Version)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
	}

	log.Info("api berhenti, menunggu request selesai")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	return srv.Shutdown(shutdownCtx)
}
