# IITK Bicycle

A campus-owned bicycle pool for everyone at IIT Kanpur. Bikes sit at stands
around campus. A rider scans the QR label on a bike, gets the code for its
combination lock, rides, and drops the bike at any stand. College staff run the
fleet from a web console. The design is multi-college from day one, so other
campuses can be added later without a rewrite.

Everything runs on free tiers: Supabase (database, auth, storage), Vercel
Hobby (admin console), OpenFreeMap tiles (maps) and GitHub Actions (CI).

## What is in this repo

| Path | What it is |
| --- | --- |
| `apps/mobile` | Rider app. Expo + expo-router, for Android, iOS and web. App ID `com.sakshamm21.iitkbicycle`. |
| `apps/admin` | Admin console. Next.js App Router + Tailwind, hosted on Vercel. |
| `packages/shared` | Database types, zod schemas and constants used by both apps. |
| `supabase` | Migrations, seed data and pgTAP database tests. |
| `e2e` | Maestro flows for the rider app. |
| `docs` | [The plan](docs/PLAN.md) and the [setup guide](docs/SETUP.md). |

## Status

Phase 0 (scaffold) is done: both apps start and show a placeholder screen.
The backend, admin console and rider app follow in the phases listed in
[docs/PLAN.md](docs/PLAN.md).

## Quick start

You need Node 20 or newer and pnpm 11.

```bash
pnpm install
```

```bash
pnpm dev:admin
```

```bash
pnpm dev:mobile
```

`pnpm dev:admin` serves the admin console at http://localhost:3000.
`pnpm dev:mobile` starts Expo; press `w` for the web build or scan the QR code
with Expo Go. See [docs/SETUP.md](docs/SETUP.md) for environment files, the
local database and the checks CI runs.

## Checks

```bash
pnpm typecheck
```

```bash
pnpm lint
```

```bash
pnpm test
```

Database tests (`pnpm db:test`) need Docker and run in CI on every push.
