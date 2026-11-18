package httpx

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteErrorEnvelope(t *testing.T) {
	cases := []struct {
		name   string
		err    error
		status int
		code   string
	}{
		{"domain", ErrNotFound, 404, "not_found"},
		{"wrapped", errors.Join(errors.New("ctx"), ErrForbidden), 403, "forbidden"},
		{"unknown", errors.New("boom"), 500, "internal"},
		{"plan limit", &Error{Status: 402, Code: "plan_limit", Message: "x", Extra: map[string]any{"trigger": "tim-ke-9"}}, 402, "plan_limit"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			WriteError(rec, httptest.NewRequest("GET", "/", nil), tc.err)
			if rec.Code != tc.status {
				t.Fatalf("status %d, mau %d", rec.Code, tc.status)
			}
			var body struct {
				Error map[string]any `json:"error"`
			}
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatal(err)
			}
			if body.Error["code"] != tc.code {
				t.Fatalf("code %v, mau %s", body.Error["code"], tc.code)
			}
			if tc.code == "plan_limit" && body.Error["trigger"] != "tim-ke-9" {
				t.Fatalf("extra tidak ikut: %v", body.Error)
			}
		})
	}
}

func TestRequestIDHeader(t *testing.T) {
	h := WithRequestID(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(RequestID(r)))
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if rec.Header().Get("X-Request-ID") == "" || rec.Body.String() != rec.Header().Get("X-Request-ID") {
		t.Fatalf("request id tidak konsisten: header=%q body=%q", rec.Header().Get("X-Request-ID"), rec.Body.String())
	}
}

func TestSPAFallbackAndInjection(t *testing.T) {
	dir := t.TempDir()
	must(t, os.WriteFile(filepath.Join(dir, "index.html"), []byte("<html><head><title>x</title></head><body></body></html>"), 0o644))
	must(t, os.MkdirAll(filepath.Join(dir, "assets"), 0o755))
	must(t, os.WriteFile(filepath.Join(dir, "assets", "app.js"), []byte("console.log(1)"), 0o644))

	h := SPA(dir, func(r *http.Request) string {
		if strings.HasPrefix(r.URL.Path, "/e/") {
			return `<meta property="og:title" content="Piala">`
		}
		return ""
	})

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/e/piala-jumat-malam-2026", nil))
	if !strings.Contains(rec.Body.String(), `og:title`) {
		t.Fatalf("meta tidak disuntikkan: %s", rec.Body.String())
	}

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/assets/app.js", nil))
	if rec.Code != 200 || !strings.Contains(rec.Header().Get("Cache-Control"), "immutable") {
		t.Fatalf("aset: status %d cache %q", rec.Code, rec.Header().Get("Cache-Control"))
	}

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/assets/tidak-ada.js", nil))
	if rec.Code != 404 {
		t.Fatalf("aset hilang harus 404, dapat %d", rec.Code)
	}
}

func TestSPAPlaceholderWithoutBuild(t *testing.T) {
	rec := httptest.NewRecorder()
	SPA(t.TempDir(), nil).ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "belum di-build") {
		t.Fatalf("placeholder tidak tampil: %d %s", rec.Code, rec.Body.String())
	}
}

func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}
