// Package payment owns Xendit xenPlatform integration (sub-accounts, payment
// requests with split rules, webhooks, refunds, payouts) and the double-entry ledger.
//
// Tables: payments, payment_webhooks, ledger_entries, payouts. PRD: F-8. Tasks: T-062..T-067.
package payment
