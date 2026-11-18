// Package backoffice is the platform admin portal: staff roles, users,
// event moderation, payments and payouts review, prices and promo codes,
// support tickets, feature flags (including maintenance mode), and audit log views.
// It only calls other modules through their services.
//
// Tables: staff_members, reports, support_tickets, ticket_messages, feature_flags, user_notes.
// PRD: F-13. Tasks: T-120..T-126.
package backoffice
