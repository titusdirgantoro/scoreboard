// Package notify sends WhatsApp (Cloud API templates) and email through
// background jobs, and tracks the per-organizer WhatsApp quota.
// While WhatsApp/SMTP credentials are empty, messages are printed to the log instead of sent.
//
// Tables: wa_messages, wa_quota_ledger. PRD: F-10. Tasks: T-071..T-075.
package notify
