# IITK Bicycle

A campus-owned bicycle pool for IIT Kanpur. Riders sign up with institutional email, wait for eligibility approval, find a bicycle and request it by its printed code. Campus attendants verify the hand-off and return; administrators manage rider approvals, fleet operations, guest invitations and issue reports.

The repo is a pnpm monorepo designed for local-first development:

| Path | What it is |
| --- | --- |
| `apps/mobile` | Expo + expo-router rider app for Android, iOS and web |
| `apps/admin` | Responsive Next.js staff console |
| `packages/shared` | Shared TypeScript models, validation and Supabase API client |
| `supabase` | PostgreSQL schema, row-level security, guarded ride RPCs, local seed data and pgTAP tests |
| `e2e` | End-to-end test planning and flows |
| `docs/PLAN.md` | Product scope and architecture |
| `docs/SETUP.md` | Exact local setup, email verification and local admin bootstrap |

## Local quick start

Requirements: Node.js 22, pnpm 11, Git and Docker.

```bash
git clone https://github.com/sakshamm21/IITKBicycle.git
cd IITKBicycle
corepack enable
corepack prepare pnpm@11.22.0 --activate
pnpm install --frozen-lockfile
pnpm db:start
pnpm db:reset
pnpm exec supabase status
```

Copy the local API URL and anon/publishable key printed by `supabase status` into the environment files:

```bash
cp apps/admin/.env.example apps/admin/.env.local
cp apps/mobile/.env.example apps/mobile/.env.local
```

Set each app's Supabase URL to `http://127.0.0.1:54321` and replace the placeholder key with the **local anon/publishable key** (never the service-role key). See [docs/SETUP.md](docs/SETUP.md) to verify a test email and bootstrap a local administrator.

Run each app in a separate terminal:

```bash
pnpm dev:admin
pnpm dev:mobile
```

- Admin console: http://localhost:3000
- Rider app: press `w` in the Expo terminal for web, or scan the Expo QR code with Expo Go
- Local Supabase Studio: http://127.0.0.1:54323
- Local email inbox: http://127.0.0.1:54324

## Checks

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build:admin
pnpm --filter @iitk-bicycle/mobile export:web
pnpm db:test
```

GitHub Actions runs typecheck, lint, unit tests, admin production build, rider web export and local database tests on pushes and pull requests.

## Security and rollout notes

- Client apps use only the Supabase anon/publishable key. Database RLS and checked RPCs enforce access; never ship a service-role key or database secret.
- Institutional email verification and eligibility approval are separate. Campus members need administrator approval; guests must be invited by an authorized administrator and verify that exact email.
- A QR label identifies the bicycle but does not operate its physical lock. This MVP uses attendant-verified release and return; it never sends a combination code to the rider app.
- The local seed contains sample stands and 30 sample bicycles. It is demo inventory, not an authoritative inventory of real campus bikes.
- Do not use the local administrator bootstrap SQL against a live project without reviewing the account and access policy first.

## Product status

The repository now includes a working local-first MVP foundation: sign-up/sign-in, email verification flow, eligibility state, bike discovery/manual code requests, attendant release/return, guest invitations, staff dashboards and issue workflow. Production launch still requires real-campus verification, an authorized production admin, mail delivery and redirect configuration, reviewed migrations, and device-level QA.
