// Package rating computes Elo ratings per sport: start 1000, K = 32,
// expected = 1 / (1 + 10^((R_opponent - R_team) / 400)), stars 1–5 derived from rating.
//
// Tables: ratings, rating_events. PRD: F-12.3, F-12.4. Task: T-113.
package rating
