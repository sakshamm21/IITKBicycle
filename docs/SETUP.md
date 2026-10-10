# Local development and first-run guide

This repository is a pnpm monorepo: Expo rider app, Next.js staff console, shared TypeScript API/types, and a local Supabase backend. The default environment examples intentionally point at **local Supabase**, not the live campus project.

## Requirements

- Node.js 22 LTS (Node 20+ is the minimum)
- pnpm 11 (the repository pins pnpm 11.22.0)
- Git
- Docker Desktop / Docker Engine, required for the local database and email testing
- A browser; Expo Go or an Android emulator is optional for the native rider app

## Start from a fresh clone

```bash
git clone https://github.com/sakshamm21/IITKBicycle.git
cd IITKBicycle
corepack enable
corepack prepare pnpm@11.22.0 --activate
pnpm install --frozen-lockfile
```

Start the local Supabase stack (first start downloads its containers):

```bash
pnpm db:start
pnpm db:reset
pnpm exec supabase status
```

Copy the local API URL and the **anon/publishable key** printed by `supabase status` into both app environment files:

```bash
cp apps/admin/.env.example apps/admin/.env.local
cp apps/mobile/.env.example apps/mobile/.env.local
```

Set `NEXT_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_URL` to `http://127.0.0.1:54321`. Replace each `REPLACE_WITH_LOCAL_ANON_OR_PUBLISHABLE_KEY` with the local anon/publishable key. Do **not** use the service-role key. Restart dev servers after changing env files.

The local email inbox is available at http://127.0.0.1:54324. Sign-up verification links are delivered there during development.

## Bootstrap a local administrator

1. Start the apps (commands below) and create an account with an `@iitk.ac.in` email address.
2. Open http://127.0.0.1:54324, open the verification email and confirm the account.
3. In the local Supabase Studio at http://127.0.0.1:54323, open **SQL Editor** and run the following after replacing the email. This bootstrap is for a disposable local database only:

```sql
update public.profiles
set role = 'super_admin', status = 'approved', updated_at = now()
where lower(email) = lower('YOUR_EMAIL@iitk.ac.in')
  and college_id = (select id from public.colleges where short_code = 'IITK');
```

4. Sign in at http://localhost:3000. This first admin can invite a guest email from **Guest access** and approve other campus riders from **Rider approvals**.

For a real hosted deployment, bootstrap the first administrator deliberately through the Supabase SQL Editor with a trusted account, then remove the bootstrap instructions/credentials from any public demo. Never commit a service-role key or admin password.

## Run the apps

Open separate terminals from the repository root:

```bash
pnpm dev:admin
```

Staff console: http://localhost:3000

```bash
pnpm dev:mobile
```

Expo shows a QR code. Press `w` for the rider web app, `a` for an Android emulator, or scan with Expo Go. For web-only:

```bash
pnpm dev:mobile:web
```

Use two browser tabs to test the rider app and staff console. Local data and accounts are isolated from the hosted campus project.

## Tests and build checks

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build:admin
pnpm db:test
```

`pnpm db:test` needs Docker and a running local Supabase stack. GitHub Actions runs typecheck, lint, unit tests, admin production build, and database tests for every push and pull request.

## Environment and secrets

- `apps/admin/.env.example` and `apps/mobile/.env.example` use local URLs and a placeholder key. Each developer creates their own ignored `.env.local`.
- Only the anon/publishable key belongs in the apps. It is designed for client use; row-level security and database functions enforce permissions.
- Never expose `SUPABASE_SERVICE_ROLE_KEY`, a database password, JWT secret, or other server secret in a mobile app, client-side environment variable, GitHub commit, or issue.
- Campus members must verify their institutional email and wait for an administrator to approve eligibility. Invited guests must use the exact invited email and verify it.
- A QR label identifies a bike; it does **not** unlock a physical lock. The first MVP deliberately uses an attendant-verified release and return. Do not put combination codes in public client data.

## Hosted services

The hosted project is not needed for local development. To connect a deployment to a hosted Supabase project, set its URL and publishable key in the deployment environment, apply reviewed migrations, and configure Auth email delivery/redirect URLs. Never point local development at production by default.
