# MNML Trade

Stock analysis platform — web (Next.js), mobile (React Native/Expo), and API (Phoenix/Elixir) in a single monorepo.

## Prerequisites

- **asdf** — runtime version manager; run `asdf install` to install Node.js, Elixir, and Erlang from `.tool-versions`
- **pnpm** 9+ — install with `corepack enable && corepack prepare pnpm@latest --activate`
- **PostgreSQL** 16+ — required for the Phoenix API

## Getting Started

```bash
# Install all workspace dependencies
pnpm install

# Start dev servers for all apps (web, mobile — API runs via mix separately)
pnpm dev

# Build all apps and packages
pnpm build
```

## Monorepo Structure

```
mnml-trade/
├── apps/
│   ├── web/          # Next.js web application
│   ├── mobile/       # React Native / Expo mobile app
│   └── api/          # Phoenix API (Elixir)
├── packages/
│   ├── types/              # Shared TypeScript types (@repo/types)
│   ├── api-client/         # HTTP client for the Phoenix API (@repo/api-client)
│   ├── ui/                 # Shared React components (@repo/ui)
│   ├── tailwind-config/    # Shared Tailwind theme (@repo/tailwind-config)
│   ├── typescript-config/  # Shared tsconfig bases (@repo/typescript-config)
│   └── utils/              # Shared utilities and validators (@repo/utils)
├── docs/                   # PRD, HLD, and milestone tickets
├── turbo.json              # Turborepo task pipeline
├── pnpm-workspace.yaml     # PNPM workspace definition
└── package.json            # Root scripts
```

## Available Scripts

All scripts use [Turborepo](https://turbo.build/) for caching and parallel execution.

| Command | Description |
|---------|-------------|
| `pnpm dev` | Start dev servers for web and mobile |
| `pnpm build` | Build all apps and packages |
| `pnpm lint` | Run linting across the monorepo |
| `pnpm type-check` | Run TypeScript type checking across the monorepo |
| `pnpm clean` | Remove build artifacts and node_modules |

### Running a single app

```bash
# Run only the web app
pnpm --filter @repo/web dev

# Run only the mobile app
pnpm --filter @repo/mobile dev

# Build only a specific package
pnpm --filter @repo/types type-check
```

### Phoenix API (apps/api)

The API is an Elixir/Phoenix project. Set it up and run it separately:

```bash
cd apps/api

# First-time setup: install deps, create DB, run migrations
mix setup

# Start the API server (default: http://localhost:4000)
mix phx.server

# Run tests
mix test
```

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check — returns `{"status": "ok"}` (200) or `{"status": "error"}` (503) |

The dev config auto-detects your system Postgres user. To override, set `PGUSER`, `PGPASSWORD`, and `PGHOST` environment variables.

## Tooling

- **Turborepo** — task orchestration, caching, and dependency-aware builds
- **PNPM** — fast, disk-efficient package manager with workspace support
- **TypeScript** — shared via `@repo/typescript-config` base configs

## Documentation

- [Product Requirements (PRD)](docs/mnml_prd.md)
- [High-Level Design (HLD)](docs/mnml_hld.md)
- [Milestone 1 Tickets](docs/milestones/milestone_1.md)
