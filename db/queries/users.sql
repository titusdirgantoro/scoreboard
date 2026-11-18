-- Contoh query sqlc untuk modul auth (T-007). Satu berkas per modul: db/queries/<modul>.sql.

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1;

-- name: GetUserByPhone :one
SELECT * FROM users WHERE phone_e164 = $1;

-- name: CreateUser :one
INSERT INTO users (id, name, email, phone_e164)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: TouchUserLastSeen :exec
UPDATE users SET last_seen_at = now() WHERE id = $1;
