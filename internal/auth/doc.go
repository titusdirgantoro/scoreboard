// Package auth owns users, login identities (Google, email OTP, WhatsApp OTP),
// sessions, and PIN access tokens for referees and verification desks.
//
// Tables: users, auth_identities, sessions, otp_codes, access_tokens (via event courts).
// PRD: F-1. Tasks: T-011..T-017, T-026.
package auth
