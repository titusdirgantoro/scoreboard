// Package config loads process configuration from environment variables.
package config

import (
	"errors"
	"fmt"
	"os"
	"strings"
)

// Config holds settings shared by the api and worker programs.
// New settings must also be added to .env.example.
//
// There is only one deployed environment: production (ADR-0008). APP_ENV=local
// exists solely for running a binary by hand (e.g. a quick smoke test of a
// fresh build); it relaxes the required secrets and uses text logs.
type Config struct {
	Env           string // prod | local
	HTTPAddr      string
	PublicBaseURL string
	LogLevel      string
	WebDistDir    string
	DatabaseURL   string
	SessionSecret string
	Version       string
}

// IsProd reports whether the process runs in production.
func (c Config) IsProd() bool { return c.Env == "prod" }

// Load reads the configuration from the environment using getenv
// (pass os.Getenv in programs; a map lookup in tests).
func Load(getenv func(string) string) (Config, error) {
	get := func(key, def string) string {
		if v := strings.TrimSpace(getenv(key)); v != "" {
			return v
		}
		return def
	}
	c := Config{
		Env:           get("APP_ENV", "prod"),
		HTTPAddr:      get("HTTP_ADDR", "0.0.0.0:8080"),
		PublicBaseURL: strings.TrimRight(get("PUBLIC_BASE_URL", "https://scoreboard.tiusapp.com"), "/"),
		LogLevel:      get("LOG_LEVEL", "info"),
		WebDistDir:    get("WEB_DIST_DIR", "web/dist"),
		DatabaseURL:   get("DATABASE_URL", ""),
		SessionSecret: get("SESSION_SECRET", ""),
		Version:       get("APP_VERSION", "unknown"),
	}
	if c.Env != "prod" && c.Env != "local" {
		return c, fmt.Errorf("APP_ENV harus prod atau local, bukan %q", c.Env)
	}
	if c.IsProd() {
		var missing []string
		if c.DatabaseURL == "" {
			missing = append(missing, "DATABASE_URL")
		}
		if len(c.SessionSecret) < 32 {
			missing = append(missing, "SESSION_SECRET (min. 32 karakter)")
		}
		if !strings.HasPrefix(c.PublicBaseURL, "https://") {
			missing = append(missing, "PUBLIC_BASE_URL (https)")
		}
		if len(missing) > 0 {
			return c, errors.New("konfigurasi produksi belum lengkap: " + strings.Join(missing, ", "))
		}
	}
	return c, nil
}

// FromEnv is Load(os.Getenv).
func FromEnv() (Config, error) { return Load(os.Getenv) }
