package httpx

import (
	"bytes"
	"errors"
	"io/fs"
	"net/http"
	"os"
	"path"
	"strings"
)

// HeadInjector returns extra <head> HTML (title, Open Graph meta) for a page path,
// e.g. the event name for /e/{slug}. Return "" to keep index.html unchanged.
// Implemented by the event module in T-024.
type HeadInjector func(r *http.Request) string

// SPA serves the built web app from dir. Existing files are served directly
// (hashed /assets/* get long cache headers); other GET paths fall back to
// index.html so client-side routing works. When dir has no build yet, a short
// placeholder page is returned instead.
func SPA(dir string, inject HeadInjector) http.Handler {
	root := os.DirFS(dir)
	files := http.FileServerFS(root)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			WriteError(w, r, NewError(http.StatusMethodNotAllowed, "method_not_allowed", "Metode tidak didukung."))
			return
		}
		p := strings.TrimPrefix(path.Clean("/"+r.URL.Path), "/")
		if p != "" && p != "index.html" {
			if st, err := fs.Stat(root, p); err == nil && !st.IsDir() {
				if strings.HasPrefix(p, "assets/") {
					w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
				}
				files.ServeHTTP(w, r)
				return
			}
			if path.Ext(p) != "" {
				http.NotFound(w, r)
				return
			}
		}
		index, err := fs.ReadFile(root, "index.html")
		if errors.Is(err, fs.ErrNotExist) {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			_, _ = w.Write([]byte(placeholderHTML))
			return
		}
		if err != nil {
			WriteError(w, r, err)
			return
		}
		if inject != nil {
			if extra := inject(r); extra != "" {
				index = bytes.Replace(index, []byte("</head>"), []byte(extra+"</head>"), 1)
			}
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-cache")
		_, _ = w.Write(index)
	})
}

const placeholderHTML = `<!doctype html><html lang="id"><head><meta charset="utf-8"><title>scoreboard</title></head>
<body style="background:#0B0D12;color:#F2F1EC;font-family:system-ui;padding:40px">
<h1>scoreboard.tiusapp.com</h1><p>API berjalan. Web belum di-build — jalankan <code>make deploy</code> (atau <code>npm run build</code> untuk uji lokal).</p></body></html>`
