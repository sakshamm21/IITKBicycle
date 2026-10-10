# IITK Bicycle: the plan

## Goal

An end-to-end bicycle pool owned by the campus and open to everyone at IIT
Kanpur. Start with IITK, then add other colleges without a rewrite.

## How it works

1. A person signs up in the rider app with their name, phone, roll number and
   college. A college admin approves them.
2. Bikes are parked at stands. Each bike has a QR label and a 4-digit
   combination lock.
3. The rider stands next to a bike, scans its QR label, and the app shows the
   current lock code. The ride starts.
4. The rider returns the bike to any stand on campus and ends the ride. The
   app shows a new code; the rider sets the lock to it and takes a photo.
5. If the new code was not set properly, the next rider can fall back to the
   previous code, and the last returner gets a strike. Too many strikes
   suspends the account.
6. College admins approve riders, watch the fleet on a live map, handle issue
   reports and force-end rides from a web console.

## Ground rules

- **Zero cost.** Free tiers only. No paid service and no billing account.
- **No secrets in the repo.** Only public values (Supabase URL and publishable
  key) are committed.
- **Security lives in the database.** Row level security on every table, and
  every sensitive action goes through a checked database function.
- **Multi-college from day one.** Every row belongs to a college and colleges
  cannot see each other's data.

## Stack

| Piece | Choice |
| --- | --- |
| Repo | pnpm monorepo, TypeScript strict |
| Rider app (`apps/mobile`) | Expo (latest SDK) with expo-router, for Android, iOS and web export |
| Maps | MapLibre (`@maplibre/maplibre-react-native` on native, `maplibre-gl` on web) with free OpenFreeMap tiles. No API key, no Google Maps. |
| Admin console (`apps/admin`) | Next.js App Router, Tailwind, shadcn/ui, hosted on Vercel Hobby |
| Shared code (`packages/shared`) | Generated database types, zod schemas, constants |
| Backend (`supabase/`) | Supabase free plan (Postgres, Auth, Storage) in Mumbai. Migrations, seed and pgTAP tests. |
| End-to-end tests (`e2e/`) | Maestro flows for the app, Playwright for the console |
| CI (`.github/workflows`) | GitHub Actions: typecheck, lint, unit tests, database tests |

App ID: `com.sakshamm21.iitkbicycle`.

## Phase 0: scaffold

- The monorepo above, with both apps starting and showing a placeholder
  screen named "IITK Bicycle".
- `supabase init`, and `.env.example` files for both apps.
- CI: install, typecheck, lint, unit tests, plus a database job that starts
  Supabase on the runner and runs `supabase test db`.
- A daily keepalive workflow so the free Supabase project never pauses.
- This plan and a README.

**Done when** both apps run locally and CI is green on GitHub.

## Phase 1: backend

### Tables

Every table except `colleges` and `audit_log` carries a `college_id`.

| Table | What it holds |
| --- | --- |
| `colleges` | name, short code, email domains, max ride minutes (default 240), strike limit (default 3), default stand radius (default 40 m), rules text, active |
| `profiles` | one per auth user: full name, phone, roll number (required), college, role (`rider`, `college_admin`, `super_admin`), status (`pending`, `approved`, `rejected`, `suspended`), optional ID photo, strikes, push token, who approved and when, rejection reason, demo flag, owner flag |
| `stands` | name, location (PostGIS point), radius, capacity, active |
| `bikes` | short code such as `K-042`, status (`available`, `in_ride`, `maintenance`, `missing`, `retired`), current stand, notes |
| `bike_locks` | per bike: current code, previous code, when it was rotated, who returned it last. **No client can read this table.** |
| `rides` | rider, bike, start and end stand, start and end time and location, status (`active`, `completed`, `force_ended`), return photo, flags |
| `issue_reports` | type (`flat_tyre`, `brakes`, `chain`, `lock_code_wrong`, `bike_missing`, `other`), note, photo, status (`open`, `in_progress`, `resolved`), who resolved it |
| `audit_log` | who did what and when |
| private schema | `app_secrets` (the QR signing key) and `app_config` (the owner email) |

### Access rules

Row level security on everything, isolated by college and by role. Riders
cannot write to rides or bikes directly. Everything that changes a ride goes
through these database functions:

| Function | What it checks and does |
| --- | --- |
| `start_ride(qr_payload, lat, lng, accuracy, is_mocked)` | Valid QR signature (HMAC), approved rider, no active ride, bike available, rider inside the stand's geofence, GPS accuracy 50 m or better, location not mocked, rate limited. Returns the current lock code. |
| `end_ride(ride_id, lat, lng, accuracy, is_mocked)` | Rider is inside any active stand of the college. Generates a new 4-digit code, keeps the previous one, returns the new one. |
| `confirm_return(ride_id, photo_path)` | Attaches the return photo. |
| `previous_code_fallback(ride_id)` | Returns the previous code and adds a strike to the last returner. |
| `approve_user`, `reject_user(reason)`, `suspend` / `reinstate` | Admin actions on riders. |
| `force_end_ride(note)` | Admin ends a ride. |
| `demo_reset()` | Puts the demo data back to its starting state. |

Reaching the strike limit suspends the account automatically. A ride is
overdue once it passes the college's max ride minutes.

### Owner account

When someone signs up with the owner email (stored in the private config, not
in this repo), their profile becomes an approved super admin marked as owner.
The database refuses to suspend, demote or delete the owner.

### Demo accounts

Demo accounts skip the geofence and mock-location checks and can start a ride
by picking a bike instead of scanning a QR. They cannot delete anything,
change non-demo users, touch the owner, or change their own password.

### Seed data

- The IITK college (email domain `iitk.ac.in`).
- About 10 well-known stands with approximate coordinates: Main Gate,
  Academic Area / Lecture Hall Complex, Library, SAC, Health Centre, Hall 1,
  Hall 5, Hall 12/13 area, Shopping Complex, New SAC / Girls Hostel area.
- About 30 bikes spread across the stands.
- Demo accounts: `demo.rider@iitkbicycle.app`, `demo.admin@iitkbicycle.app`,
  `demo.super@iitkbicycle.app`.

### Storage

Private buckets `ride-photos` and `id-cards`. Riders write to their own
folder; college admins can read.

### Tests

pgTAP tests for approvals, starting and ending rides, double booking, the
geofence, the previous-code fallback, strikes, owner protection, demo
restrictions and cross-college isolation. TypeScript types are generated into
`packages/shared`.

**Done when** `supabase test db` passes in CI.

## Phase 2: admin console

Thirteen pages, deployed on Vercel:

1. Sign in, with one-click "Try the demo" buttons
2. Dashboard
3. Approvals
4. Users
5. Live map
6. Rides
7. Bikes
8. QR label sheet (printable)
9. Stands
10. Issues
11. College settings
12. Colleges (super admin only)
13. Audit log

Plus public privacy and account-deletion pages.

## Phase 3: rider app

Fifteen screens, also exported to web:

1. Welcome
2. Sign in
3. Sign up, with a college picker
4. Pending approval
5. Rejected / suspended
6. Home map
7. Stand list
8. Stand detail
9. Scanner, with manual code entry and a demo bike picker
10. Unlock code
11. Active ride
12. End ride, with the new code and a photo
13. Ride summary and history
14. Report an issue
15. Profile and help, with delete account

## Phase 4: hardening

- Push notifications (Expo push)
- Overdue ride reminders
- Strikes shown and explained in the app
- Error and empty states everywhere
- Maestro and Playwright test suites

## Phase 5: release

- Android APK
- Store-ready build config and assets
- iOS Simulator run (needs a Mac)
- Demo guide
- Share links
