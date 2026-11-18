# Model data

PostgreSQL. Konvensi berlaku untuk semua tabel:

- Kunci utama `id uuid` (UUIDv7 dibuat di Go; `DEFAULT gen_random_uuid()` sebagai cadangan).
- `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at` di tabel yang bisa diubah.
- Uang: `bigint` Rupiah utuh dengan sufiks `_idr`. Tidak pernah `numeric`/`float`.
- Telepon: format E.164 (`+62812…`). Email: `citext`.
- Status: `text` + `CHECK (status IN (…))` (lebih mudah dimigrasi daripada enum).
- Hapus lunak hanya di tabel yang disebut (`deleted_at`); sisanya hapus keras atau arsip.
- Kolom JSON (`jsonb`) hanya untuk konfigurasi/detail yang tidak di-query per kolom.

Tanda **[M1]** = sudah ada di migrasi `00001`, **[M2]** = `00002`; sisanya dibuat oleh tugas di `docs/TASKS.md`.

## Identitas & akses (modul `auth`, `org`)

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `users` [M1] | id, name, email citext uniq null, phone_e164 uniq null, avatar_key, status (`active`,`suspended`), suspended_reason, last_seen_at | Minimal salah satu email/telepon |
| `auth_identities` [M1] | id, user_id, provider (`google`,`email`,`whatsapp`), subject, created_at | Unik (provider, subject) |
| `sessions` [M1] | id, user_id, token_hash bytea uniq, user_agent, ip inet, expires_at, revoked_at | Token mentah hanya di cookie |
| `otp_codes` [M1] | id, channel (`email`,`whatsapp`), destination, code_hash, purpose (`login`,`verify_phone`), attempts, expires_at, consumed_at | Maks 5 percobaan |
| `organizations` [M1] | id, name, slug uniq, owner_user_id, xendit_sub_account_id, payout_bank_code, payout_account_masked, payout_account_name | Satu pengguna bisa punya beberapa org |
| `org_members` [M1] | org_id, user_id, role (`owner`,`admin`,`treasurer`), invited_by, created_at | PK (org_id, user_id) |
| `org_invites` | id, org_id, contact, role, token_hash, expires_at, accepted_at | Undangan admin/bendahara |
| `audit_log` [M1] | id bigserial, actor_user_id, actor_kind (`user`,`staff`,`system`,`pin`), org_id, event_id, action, target_type, target_id, reason, meta jsonb, ip, created_at | Hanya tambah, tidak pernah diubah |

## Event (modul `event`)

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `events` [M2] | id, org_id, slug uniq, name, sports text[], format, starts_on date, ends_on date, venue, visibility (`public`,`link`,`private`), viewer_pin_hash, status (`draft`,`published`,`archived`), reg_open bool, reg_closes_at, fee_idr, team_quota, theme jsonb, plan (`free`,`pass16`,`pass32`,`pass64`,`pro`), pass_expires_at, published_at, deleted_at | `theme`: name, primary, accent, mode, shape, logo_key |
| `courts` [M2] | id, event_id, code (`l1`…), name, sport, referee_name, pin_hash, pin_version int, sort_order | Ganti PIN = `pin_version + 1` |
| `access_tokens` [M2] | id, event_id, court_id null, kind (`referee`,`desk`), token_hash uniq, pin_version, expires_at, revoked_at, device_label | Token PIN wasit/meja |
| `event_crew` | id, event_id, name, contact, role (`referee`,`desk`), court_id null | Panitia tanpa akun |
| `announcements` | id, event_id, title, body, audience (`all`,`managers`,`crew`), channel (`page`,`share`,`whatsapp`), recipients int, created_by, created_at | |
| `sponsors` | id, event_id/org_id, name, logo_key, link, placement text[] | Paket Pro |

## Peserta (modul `registration`)

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `teams` [M2] | id, event_id, name, sport, captain_name, captain_phone_e164, manager_user_id null, status (`pending`,`accepted`,`rejected`), reject_reason, roster_count, registered_at | Unik (event_id, lower(name)) |
| `players` [M2] | id, team_id, full_name, jersey_no, position, birth_date, photo_key, emergency_contact, status (`eligible`,`suspended`,`docs_missing`), yellow_cards, red_cards, guardian_consent_at | Kode kartu: `{EVT}-{TIM}-{NO}` |
| `player_checks` | id, player_id, match_id, checked_by_token_id, result, created_at | Log meja verifikasi |

## Kompetisi & laga (modul `competition`, `match`, `live`)

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `stages` | id, event_id, sport, kind (`group`,`knockout`,`double_elim`,`league`,`americano`,`mexicano`), name, config jsonb, sort_order | config: jumlah grup, lolos per grup, Bo |
| `stage_groups` | id, stage_id, name | Grup A, B, … |
| `stage_entries` | stage_id, group_id null, team_id, seed | |
| `matches` [M2] | id, event_id, stage_id null, round, slot, court_id null, scheduled_at, team_a_id, team_b_id, sport, rules jsonb, status (`scheduled`,`live`,`finished`,`walkover`,`cancelled`), score_a, score_b, detail jsonb, winner_team_id, live_version bigint, started_at, finished_at | `detail`: gim/set per periode; `rules`: format aturan (mis. 3×21) |
| `score_events` [M2] | id bigserial, match_id, client_id text, seq int, kind (`point`,`undo`,`period`,`card`,`timeout`,`finish`), payload jsonb, source (`referee`,`admin`), token_id null, user_id null, client_ts, server_ts | Unik (match_id, client_id, seq) |
| `score_corrections` [M2] | id, match_id, before jsonb, after jsonb, reason, actor_user_id, created_at | Riwayat koreksi |
| `standings` | stage_id, group_id, team_id, played, won, drawn, lost, gf, ga, points, updated_at | Turunan, dihitung ulang dari laga |
| `schedule_runs` | id, event_id, params jsonb, result jsonb, conflicts int, published_at | Riwayat jadwal otomatis |

## Uang (modul `billing`, `payment`)

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `plan_prices` | code (`pass16`,`pass32`,`pass64`,`community`,`pro`,`trx_fee`,`wa100`,`free_teams`), amount_idr, updated_by, updated_at | Diubah dari backoffice |
| `promo_codes` | code uniq, percent, quota, used, scope, active | |
| `purchases` | id, org_id, user_id, product, event_id null, amount_idr, discount_idr, promo_code, status (`pending`,`paid`,`failed`,`refunded`), payment_id | Pembelian paket/kuota |
| `subscriptions` | id, org_id, plan (`community`,`pro`), status, current_period_end | |
| `payments` | id, org_id, event_id, team_id null, purchase_id null, provider (`xendit`,`cash`), provider_ref, method (`qris`,`va`,`ewallet`,`cash`), amount_idr, fee_idr, status (`pending`,`paid`,`failed`,`expired`,`refunded`), idempotency_key uniq, paid_at | |
| `payment_webhooks` | id, provider, provider_event_id uniq, payload jsonb, processed_at | Idempotensi webhook |
| `ledger_entries` | id bigserial, txn_id uuid, account, amount_idr (bertanda), ref_type, ref_id, created_at | Σ per txn_id = 0 |
| `payouts` | id, org_id, amount_idr, bank, status (`requested`,`approved`,`processing`,`paid`,`held`,`failed`), reviewed_by, hold_reason, provider_ref | |

## Notifikasi & media (modul `notify`, `media`, `certificate`)

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `wa_messages` | id, org_id, event_id, to_phone_e164, template, variables jsonb, status (`queued`,`sent`,`delivered`,`read`,`failed`), provider_msg_id, cost_units, created_at | |
| `wa_quota_ledger` | id, org_id, delta int, reason, ref_id, created_at | Saldo = Σ delta |
| `media_objects` | id, owner_type, owner_id, key, mime, width, height, bytes, variant_of null, kind (`original`,`cutout`,`thumb`) | |
| `certificates` | id, event_id, recipient_type (`team`,`player`), recipient_id, recipient_name, rank_label, style, texts jsonb, code uniq, status (`draft`,`issued`,`sent`), issued_at, pdf_key | |
| `story_renders` | id, match_id, layout, look, sticker, watermark bool, image_key, created_at | Statistik berbagi |

## Komunitas & rating (modul `community`, `rating`)

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `groups` | id, owner_user_id, org_id null, name, sport, capacity, default_fee_idr | Paket Komunitas |
| `group_members` | group_id, user_id null, display_name, phone_e164, rating_override | Anggota bisa tanpa akun |
| `group_sessions` | id, group_id, starts_at, venue, capacity, fee_total_idr, status | Jadwal main bareng |
| `rsvps` | session_id, member_id, status (`going`,`maybe`,`no`,`waitlist`), paid_idr, paid_at | |
| `team_splits` | id, session_id null, input jsonb, result jsonb, created_by, created_at | |
| `ratings` | id, subject_type (`member`,`user`), subject_id, sport, rating int, games int, updated_at | Elo, mulai 1000 |
| `rating_events` | id, rating_id, match_ref, delta int, before int, after int, created_at | |

## Backoffice (modul `backoffice`)

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `staff_members` | user_id PK, role (`superadmin`,`support`,`finance`,`moderator`), active | |
| `reports` | id, target_type, target_id, reason, reporter_contact, status (`open`,`actioned`,`dismissed`), handled_by | Laporan konten |
| `support_tickets` | id, org_id null, user_id null, subject, status (`open`,`replied`,`closed`), plan_snapshot | |
| `ticket_messages` | id, ticket_id, from_staff bool, author_name, body, created_at | |
| `feature_flags` | key PK, enabled, meta jsonb, updated_by | termasuk `maintenance` |
| `user_notes` | id, user_id, staff_user_id, body, created_at | |

## Indeks wajib

- `events (slug)`, `events (org_id, status)`, `teams (event_id, status)`, `matches (event_id, status, scheduled_at)`, `matches (court_id, status)`, `score_events (match_id, id)`, `payments (event_id, status)`, `ledger_entries (account, created_at)`, `audit_log (org_id, created_at desc)`, `sessions (user_id)`, `otp_codes (destination, created_at desc)`.
