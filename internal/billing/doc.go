// Package billing owns plans, prices, Pass Event, subscriptions, promo codes,
// and entitlements. Other modules call Entitlements() and return the
// plan_limit error (HTTP 402) when a limit is hit (docs/ARCHITECTURE.md §10).
//
// Tables: plan_prices, promo_codes, purchases, subscriptions. PRD: F-9. Tasks: T-060, T-061, T-065, T-068.
package billing
