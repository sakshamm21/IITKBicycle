# Setup guide

## Requirements

- Node 20 or newer (CI uses Node 22)
- pnpm 11 (`npm install -g pnpm`)
- Git
- Docker Desktop, only if you want to run the database locally. CI runs the
  database tests for you, so this is optional.

## Install

```bash
pnpm install
```

## Environment files

Both apps read the Supabase URL and publishable key from an env file. These
two values are public and are already in the example files, so copying them is
enough.

```bash
cp apps/admin/.env.example apps/admin/.env.local
```

```bash
cp apps/mobile/.env.example apps/mobile/.env.local
```

Never put a Supabase secret or service-role key in these files or anywhere in
the repo. Real `.env` files are git-ignored.

## Run the apps

| Command | What it does |
| --- | --- |
| `pnpm dev:admin` | Admin console at http://localhost:3000 |
| `pnpm dev:mobile` | Expo dev server. Press `w` for web, `a` for an Android emulator, or scan the QR code with Expo Go. |
| `pnpm dev:mobile:web` | Rider app in the browser directly |
| `pnpm build:admin` | Production build of the admin console |

## Checks

| Command | What it does |
| --- | --- |
| `pnpm typecheck` | TypeScript, strict, in every package |
| `pnpm lint` | ESLint in every package |
| `pnpm test` | Unit tests (Vitest) |

## Local database (optional, needs Docker)

| Command | What it does |
| --- | --- |
| `pnpm db:start` | Start a local Supabase stack |
| `pnpm db:reset` | Re-apply all migrations and the seed |
| `pnpm db:test` | Run the pgTAP tests in `supabase/tests` |
| `pnpm db:types` | Regenerate `packages/shared/src/database.types.ts` |
| `pnpm db:stop` | Stop the stack |

## Hosted services

- **Supabase**: project `jwyamfjoisycodwelpys` (free plan, Mumbai). Migrations
  in `supabase/migrations` are applied to it after they are reviewed in a pull
  request.
- **Keepalive**: `.github/workflows/keepalive.yml` pings the project daily so
  the free plan does not pause it. GitHub turns scheduled workflows off after
  60 days without a commit; re-enable it from the Actions tab if that happens.
- **Vercel**: hosts `apps/admin` on the Hobby plan (set up in Phase 2).
