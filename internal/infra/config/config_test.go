package config

import "testing"

func env(m map[string]string) func(string) string { return func(k string) string { return m[k] } }

func TestDefaultIsProdAndRequiresSecrets(t *testing.T) {
	if _, err := Load(env(nil)); err == nil {
		t.Fatal("bawaan prod tanpa rahasia seharusnya gagal")
	}
	c, err := Load(env(map[string]string{
		"DATABASE_URL":    "postgres://x",
		"SESSION_SECRET":  "0123456789abcdef0123456789abcdef",
		"PUBLIC_BASE_URL": "https://scoreboard.tiusapp.com/",
	}))
	if err != nil {
		t.Fatalf("prod lengkap gagal: %v", err)
	}
	if !c.IsProd() || c.HTTPAddr != "0.0.0.0:8080" {
		t.Fatalf("bawaan tidak sesuai: %+v", c)
	}
	if c.PublicBaseURL != "https://scoreboard.tiusapp.com" {
		t.Fatalf("garis miring akhir tidak dibuang: %q", c.PublicBaseURL)
	}
}

func TestLocalRelaxesSecrets(t *testing.T) {
	c, err := Load(env(map[string]string{"APP_ENV": "local", "HTTP_ADDR": "127.0.0.1:18080"}))
	if err != nil {
		t.Fatalf("local seharusnya tidak butuh rahasia: %v", err)
	}
	if c.IsProd() || c.HTTPAddr != "127.0.0.1:18080" {
		t.Fatalf("local tidak sesuai: %+v", c)
	}
}

func TestRejectsOtherEnvironments(t *testing.T) {
	for _, e := range []string{"dev", "staging"} {
		if _, err := Load(env(map[string]string{"APP_ENV": e})); err == nil {
			t.Fatalf("APP_ENV=%s seharusnya ditolak (hanya prod/local)", e)
		}
	}
}
