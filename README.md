# Stem

[![Crystal](https://img.shields.io/badge/crystal-1.18.2-000000?logo=crystal&logoColor=white)](https://crystal-lang.org/)
[![Build](https://github.com/FlorexLabs/stem/actions/workflows/ci.yml/badge.svg)](https://github.com/FlorexLabs/stem/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/FlorexLabs/stem?color=0aa387)](LICENSE)

---

> [!WARNING]
> Stem is a **work in progress** and is not yet ready for production use. Stay for future updates!

> **Stem** is the backend API for the [Florex](https://github.com/FlorexLabs)
> stack ([Stem](https://github.com/FlorexLabs/stem) + [Bloom](https://github.com/FlorexLabs/bloom) + Seed + Root).  
> It's a **Lucky (Crystal) API‑only app** that exposes services, health, and auth endpoints for the Bloom dashboard.

---

* [Stem](#stem)
    * [Features](#features)
    * [Stack Overview](#stack-overview)
    * [Endpoints Overview](#endpoints-overview)
    * [Quick Start (local)](#quick-start-local)
    * [Database & Migrations](#database--migrations)
    * [Seed Data](#seed-data)
    * [Docker Development](#docker-development)
    * [Environment Variables](#environment-variables)
    * [Project Structure](#project-structure)
    * [Available Tasks](#available-tasks)
    * [License](#license)

## Features

- ✅ **API‑only Lucky application**
- ✅ JSON endpoints for:
    - `/api/health` – health check
    - `/api/services` – list/create/delete monitored services
    - `/api/sign_ins`, `/api/sign_ups` – token‑based auth (JWT)
    - `/api/me` – current user info (when auth is enabled)
- ✅ **PostgreSQL** via **Avram** (Lucky's ORM + migrator)
- ✅ Optional demo seed data for services
- ✅ CORS middleware for cross‑origin access from Bloom (Vue dashboard)
- ✅ Ready to containerize with `docker compose`

---

## Stack Overview

| Tool               | Purpose                              |
|--------------------|--------------------------------------|
| **Crystal 1.18+**  | Language                             |
| **Lucky**          | Web framework (API‑only)             |
| **Avram**          | ORM + migrations                     |
| **Authentic**      | Password hashing/auth                |
| **JWT**            | Token‑based authentication           |
| **PostgreSQL**     | Primary database                     |
| **docker compose** | Optional dev environment (Stem + DB) |

---

## Endpoints Overview

Current main endpoints (all return JSON):

- `GET /api/health`  
  Simple health check: `{ "ok": true, "version": "0.1.0" }`.

- `GET /api/services`  
  List services:
  ```json
  [
    {
      "id": 1,
      "name": "rails-api",
      "type": "Rails",
      "status": "ok",
      "responseTime": 145,
      "lastCheck": "2 min ago",
      "sparkline": []
    },
    ...
  ]
  ```

- `POST /api/services`  
  Create a new service. Example body:
  ```json
  {
    "name": "my-service",
    "type": "Node.js",
    "url": "https://service.example.com",
    "checkInterval": 60,
    "timeout": 30
  }
  ```

- `DELETE /api/services/:id`  
  Delete a service by ID.

- `POST /api/sign_ups`  
  Create a user and return a JWT:
  ```json
  {
    "user": {
      "email": "me@example.com",
      "password": "password",
      "password_confirmation": "password"
    }
  }
  ```

- `POST /api/sign_ins`  
  Sign in and get a JWT.

- `GET /api/me`  
  Return the current user's basic info when provided with a valid `Authorization: Bearer <token>` header.

Depending on configuration, authentication can be globally required or selectively skipped per action.

---

## Quick Start (local)

Requirements:

- Crystal ≥ 1.18.x
- PostgreSQL ≥ 18.x

1. Clone and install:

```bash
git clone https://github.com/FlorexLabs/stem.git
cd stem

shards install
```

2. Configure database for local dev

Edit `.env` (already present) to match your local Postgres:

```env
LUCKY_ENV=development
PORT=3000

DB_HOST=127.0.0.1
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_NAME=florex

SECRET_KEY_BASE=<use `lucky gen.secret` or existing value>
```

3. Create and migrate DB:

```bash
lucky db.create
lucky db.migrate
```

4. (Optional) Seed demo data:

```bash
lucky db.seed
# or for just sample data:
lucky db.seed.sample_data
```

5. Run the dev server:

```bash
lucky dev
```

The API will be available at `http://localhost:3000`.

Test:

```bash
curl http://localhost:3000/api/health
curl http://localhost:3000/api/services
```

---

## Database & Migrations

Stem uses **Avram** for migrations.

- Migrations live in `db/migrations/`:
    - `00000000000001_create_users.cr`
    - `2025XXXXXXXXXX_create_services.cr`
    - etc.

Create a new model + migration:

```bash
lucky gen.model ServiceMetric \
  service : Service \
  response_ms : Int32 \
  status : String \
  ts : Time
```

Run migrations:

```bash
lucky db.migrate
```

In development, the server also calls:

```crystal
Avram::Migrator::Runner.new.ensure_migrated!
Avram::SchemaEnforcer.ensure_correct_column_mappings!
```

on startup (`src/start_server.cr`), to keep schema and models in sync.

---

## Seed Data

Two seed tasks are available:

- `tasks/db/seed/required_data.cr`  
  For **required** baseline data (currently minimal).

- `tasks/db/seed/sample_data.cr`  
  Seeds example `Service` records used by the Bloom dashboard mock:

  ```bash
  lucky db.seed.sample_data
  ```

Run all seed tasks:

```bash
lucky db.seed
```

---

## Docker Development

A simple dev setup is provided using `docker compose`:

- `db` – Postgres (18.1‑alpine)
- `lucky` – Crystal + Lucky dev server

`docker/development.dockerfile` builds a Crystal image with Lucky CLI for development, and `docker/dev_entrypoint.sh`:

- installs shards,
- waits for Postgres,
- runs migrations if needed,
- starts `lucky dev`.

To run everything in Docker:

```bash
docker compose up --build
```

The API is then available at `http://localhost:3000`.

You can still use `.env` for local (non‑Docker) development; the compose file sets its own DB_* env for the containers.

---

## Environment Variables

Common variables:

| Variable          | Purpose                               | Example                             |
|-------------------|---------------------------------------|-------------------------------------|
| `LUCKY_ENV`       | Lucky environment (`development` etc) | `development`                       |
| `PORT`            | HTTP port                             | `3000`                              |
| `DB_HOST`         | DB host                               | `127.0.0.1` or `db` in Docker       |
| `DB_PORT`         | DB port                               | `5432`                              |
| `DB_USERNAME`     | DB user                               | `postgres` / `lucky`                |
| `DB_PASSWORD`     | DB password                           | `postgres` / `password`             |
| `DB_NAME`         | DB database name                      | `florex` / `lucky`                  |
| `DATABASE_URL`    | (Prod) full DB URL                    | `postgres://user:pass@host:5432/db` |
| `SECRET_KEY_BASE` | Lucky's secret key for JWT, etc.      | output of `lucky gen.secret`        |
| `CORS_ORIGIN`     | Allowed origin for CORS               | `http://localhost:5173` (Bloom dev) |

In development:

- `config/database.cr` uses `DATABASE_URL` if present; otherwise it uses `DB_*` values.
- In production (`LUCKY_ENV=production`), `DATABASE_URL` is required.

---

## Project Structure

Key files and directories:

```text
stem/
├─ src/
│  ├─ stem.cr              # compiled entry (requires start_server)
│  ├─ start_server.cr      # starts AppServer
│  ├─ app_server.cr        # Lucky::BaseAppServer + middleware (CORS, errors)
│  ├─ app.cr               # requires shards, config, models, actions, etc.
│  ├─ app_database.cr      # Avram::Database subclass
│  ├─ actions/             # API actions (controllers)
│  │  ├─ api/
│  │  │  ├─ health/show.cr
│  │  │  ├─ services/*.cr
│  │  │  ├─ sign_ins/*.cr
│  │  │  ├─ sign_ups/*.cr
│  │  │  └─ me/show.cr
│  │  ├─ errors/show.cr
│  │  └─ home/index.cr
│  ├─ middleware/          # e.g. CorsHandler
│  ├─ models/              # User, Service, etc.
│  ├─ operations/          # Save/SignIn/SignUp ops
│  ├─ queries/             # Avram query objects
│  ├─ serializers/         # JSON serializers
│  └─ helpers/             # e.g. TimeHelper
├─ db/
│  ├─ migrations/          # Avram migrations
│  └─ structure.sql        # (optional) schema dump
├─ docker/
│  ├─ development.dockerfile
│  ├─ dev_entrypoint.sh
│  └─ wait-for-it.sh
├─ compose.yml             # Docker dev compose (db + lucky)
├─ .env                    # Local development env vars
├─ shard.yml               # Shards config
├─ shards.lock
└─ README.md               # this file
```

---

## Available Tasks

Run tasks with `lucky`:

| Command                     | Description                        |
|-----------------------------|------------------------------------|
| `lucky dev`                 | Start the dev server               |
| `lucky db.create`           | Create database                    |
| `lucky db.migrate`          | Run migrations                     |
| `lucky db.rollback`         | Roll back last migration           |
| `lucky db.schema.dump`      | Export schema to `structure.sql`   |
| `lucky db.seed`             | Run all seed tasks                 |
| `lucky db.seed.sample_data` | Seed demo services                 |
| `lucky gen.model`           | Generate model + query + migration |
| `lucky routes`              | Show defined routes                |

---

## License

This project is released under the [MIT License](LICENSE).

---

© 2025 Florex Labs.  
Stem powers the backend of Florex so your systems can bloom.
