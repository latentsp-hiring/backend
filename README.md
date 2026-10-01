# Tidewater: Argyle Paystub Sync, Take-Home Assignment

## Your Task

Build a service that receives Argyle paystub webhooks, validates them, and syncs the
account's paystubs from the Argyle API into a database. Use any language and framework you
like.

**Time estimate:** 1.5 hours

---

## What You'll Build

A service in a Docker image that meets this contract.

| Endpoint | What it does |
|---|---|
| `POST /webhooks/argyle` | Receives Argyle webhook deliveries |
| `POST /internal/sync` | Starts a sync for `{"userId", "incomeId", "argyleUserId", "argyleAccountId"}` and answers `202` with `{"run_id": "<id>"}` right away |
| `GET /healthz` | Answers `200` once the service can take traffic |

Your service gets these environment variables:

| Variable | What it is |
|---|---|
| `PORT` | The port to listen on |
| `DATABASE_PATH` | The SQLite database to use (see [Database](#database)) |
| `ARGYLE_BASE_URL` | The Argyle API |
| `ARGYLE_API_ID`, `ARGYLE_API_SECRET` | Basic-auth credentials for the Argyle API |
| `ARGYLE_WEBHOOK_SECRET` | The secret webhook deliveries are signed with |

The API is documented in [`docs/api/`](docs/api/): [overview](docs/api/overview.md),
[paystubs](docs/api/paystubs.md) and [webhooks](docs/api/webhooks.md).

---

## Acceptance Criteria

### Webhook handler (`POST /webhooks/argyle`)
- [ ] Verify the `X-Argyle-Signature` header (HMAC-SHA512 of the raw body): return 401 if invalid
- [ ] Validate the payload: return 400 if invalid
- [ ] Log every delivery to `webhook_events`, failures included
- [ ] For the paystub events the provider sends: find the income by `external_account_id`, record a `sync_runs` row, and run the sync
- [ ] Return 200 on success

### Sync
- [ ] Fetch the account's paystubs from the Argyle API, handling pagination
- [ ] Upsert paystubs: insert new ones, update existing ones (matched by `external_id`)
- [ ] Move the `sync_runs` row through `running` to `succeeded` or `failed`

### Service
- [ ] `POST /internal/sync` and `GET /healthz` as in the table above
- [ ] A `Dockerfile` whose final stage builds `FROM ghcr.io/latentsp-hiring/tidewater-base:1`

> **The acceptance criteria are the floor, not the ceiling.** They describe what the
> integration does when everything goes right. See "Don't assume the other side behaves"
> below.

---

## Don't assume the other side behaves

You are integrating with a system you do not control, over a network you do not control.
The mock server is written to behave like a real third-party provider rather than a
well-mannered test fixture: it does not always do what its documentation implies, and it
does not always do the same thing twice.

We are not going to tell you how it misbehaves — working that out is part of the exercise.
Run it, send it traffic, watch what actually arrives at your endpoint and what the API
actually returns, and decide for yourself what your code needs to survive.

Then say in your write-up what you found and what you chose to handle. **We would much
rather read "I noticed X and deliberately didn't handle it because Y" than see it silently
unhandled.** Deciding what to skip in 1.5 hours is part of the answer, and we grade the
reasoning, not just the code.

---

## The service contract

Your `Dockerfile` can use any stack in earlier stages. Its **final stage** must build
`FROM ghcr.io/latentsp-hiring/tidewater-base:1` (its source is in
[`images/base/`](images/base/)) and put two executables in place:

- **`/app/start`** starts your service in the foreground.
- **`/app/migrate`** prepares the database. The base image already ships a default that
  applies `migrations/*.sql` in filename order, so most people never touch it. You may
  replace it with your own tool (for example a wrapper around `bin/rails db:migrate` or
  `mix ecto.migrate`); a replaced `/app/migrate` is yours to maintain.

A minimal Dockerfile for a Python service:

```dockerfile
FROM ghcr.io/latentsp-hiring/tidewater-base:1
COPY . /app
RUN chmod +x /app/start
```

You do not need Docker on your own machine: run your service directly while you work,
and use the practice validator below to check the image builds.

---

## Database

The grader creates the SQLite database at `$DATABASE_PATH` from
[`contract/schema.sql`](contract/schema.sql) and [`contract/seed.sql`](contract/seed.sql),
then runs your `/app/migrate`. Your service must not create or change tables at runtime:
put schema changes in `migrations/NNNN_description.sql`.

You may **extend** the schema freely: new tables, columns, indexes and constraints. You
must **never remove or retype** these columns, because the grader reads them:

- `paystubs`: `external_id`, `user_id`, `gross_pay` (REAL)
- `sync_runs`: `id`, `user_id`, `status`, `created_at`
- `webhook_events`: `failed_at`, `error`
- `incomes`: `external_account_id`, and the seeded rows in `users` and `incomes`

Build your local database the same way the grader does (needs the `sqlite3` CLI):

```bash
./scripts/init-db          # macOS / Linux
.\scripts\init-db.ps1      # Windows (PowerShell)
```

This writes `data/dev.db`. **Commit `data/dev.db` with your work**, including the traffic
your service recorded while you developed against the mock.

---

## Setup

### Requirements
- The toolchain for the stack you choose
- The `sqlite3` CLI
- macOS, Linux, or Windows

### Run the mock and your service

```bash
./scripts/run-mock-server                     # Terminal 1: the Argyle mock, on :8080
sh scripts/init-db                            # once, and whenever you add a migration
PORT=3000 DATABASE_PATH=data/dev.db \
ARGYLE_BASE_URL=http://localhost:8080 ARGYLE_API_ID=mock-id ARGYLE_API_SECRET=mock-secret \
ARGYLE_WEBHOOK_SECRET=your-webhook-secret  <start your service>   # Terminal 2
```

---

## Testing Your Implementation

### 1. Register your webhook

```bash
curl -X POST http://localhost:8080/webhooks \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test",
    "url": "http://localhost:3000/webhooks/argyle",
    "secret": "your-webhook-secret",
    "events": ["paystubs.added", "paystubs.fully_synced", "paystubs.updated"]
  }'
```

> The `secret` must match your `ARGYLE_WEBHOOK_SECRET`.

### 2. Trigger a test sync

```bash
curl -X POST http://localhost:8080/simulate/connect-seeded
```

This uses the pre-seeded account ID (`019b41d0-7a84-72db-beab-4f62f8e86ce4`) that matches a database income record.

### 3. Verify

Look at `data/dev.db` (`sqlite3 data/dev.db 'select count(*) from paystubs'`).

---

## Practice validator

```bash
./run.sh validate --preflight      # builds your image and checks it starts and is wired up
./run.sh validate                  # a scored attempt: PASS n / m
```

`--preflight` tells you exactly what is wrong when your image does not build, start, or
reach its database. It does not use an attempt; you can run it 20 times a day. A scored
attempt reports only how many checks passed, never which. You have **three**, so save
them for when you think you are done.

---

## Mock Server API

| Endpoint | Description |
|----------|-------------|
| `POST /webhooks` | Register webhook URL |
| `POST /simulate/connect-seeded` | Trigger webhooks for seeded account |
| `GET /paystubs?account={id}&limit={n}` | List paystubs (paginated via `next`/`previous` cursor URLs) |

See [`docs/api/`](docs/api/) for the full reference.

It injects failures from two directions, each with its own flag: `--chaos-level <0-100>`
(default: 25) governs the webhook deliveries it sends you, and `--api-chaos-level <0-100>`
(default: 25) governs the responses it returns from its own REST endpoints. You can turn
either up — or set both to `0` if you want a quiet baseline while you get the happy path
working.

---

## Constraints & notes

- **AI / coding agents are welcome for the code.** Use Copilot, Cursor, Claude, ChatGPT,
  or whatever you like — we expect you to. How you use them, and where you apply your own
  judgment on top, is part of what we're interested in.
- **`WRITEUP.md` is yours alone.** Do not use an AI to write it. It is short, and it is
  the part of the submission we read most carefully — we want your reasoning in your
  words, not a model's summary of your code. Non-native English, typos and rough edges are
  completely fine and are never held against you.
- Commit as you go. We read the git history, and an honest history with dead ends in it
  reads better than one tidy commit.

---

## Write-up

Add a `WRITEUP.md` at the repo root. Keep it short — half a page to a page is plenty.
Cover:

1. **What you found.** What does the other side actually do that the spec doesn't mention?
2. **What you handled, and how.** The design decisions you'd defend in review.
3. **What you deliberately didn't handle,** and why — time, risk, or judgment.
4. **What you'd do next** with another day.

---

## Required artifacts

Commit these with your work:

- your service's source and a `Dockerfile` at the repo root
- `data/dev.db`, the database your service wrote while you developed
- `migrations/`, if you changed the schema
- `WRITEUP.md`
- your git history as it happened: please do not squash it

---

## Repository layout

```
docs/api/                 # the Argyle API reference
contract/schema.sql       # the database the grader creates
contract/seed.sql         # its fixture rows
migrations/               # your schema changes, applied by /app/migrate
data/dev.db               # yours: commit it
images/base/              # source of the base image your Dockerfile builds FROM
scripts/run-mock-server   # runs the Argyle mock
scripts/init-db           # builds data/dev.db the way the grader builds its database
bin/
  argyle-mock-*           # mock Argyle server (do not edit)
  latent-cli-*            # submission CLI (do not edit)
run.sh / run.ps1          # submission wrappers (macOS·Linux / Windows)
Dockerfile                # yours
WRITEUP.md                # yours
```

---

## Submission

When you're ready to submit, use the provided CLI to bundle and upload your repository.
From the root of your assignment repo:

```bash
./run.sh publish        # macOS / Linux
.\run.ps1 publish       # Windows (PowerShell)
```

This bundles your git repository — including the `.git` history we review, and respecting
`.gitignore` (so `.env`, `node_modules`, etc. are excluded) — and uploads it to our
evaluation system.

### Your AI conversations

If you used AI coding tools, `publish` asks whether to include your conversations with them
for this task (`[Y/n]`). It's optional, and you can submit either way. If it finds none on
your computer, for example because you chatted in a browser, it asks for the path to an
exported copy instead (Enter skips). Credentials and personal details such as emails and
phone numbers are removed before upload. To answer without the prompt, pass
`--transcripts=yes` or `--transcripts=no`.

### Providing Your Email

The CLI needs your email address to notify you that the upload succeeded. It will:

1. First try to read your email from `git config user.email`
2. If it is not set, prompt you to enter it interactively
3. Alternatively, pass it directly: `./run.sh publish --email you@example.com`

### Confirmation

After the upload completes, you will be asked to reply to the email you received for this
assignment with your name and the repository name. Please send that reply so we can match
your submission to your application.

---

## Documentation

- [`docs/api/`](docs/api/): the reference for the mock you integrate against. Start here.
- [Argyle Paystubs Webhooks](https://docs.argyle.com/api-reference/paystubs-webhooks) and
  [Argyle Paystubs API](https://docs.argyle.com/api-reference/paystubs): the real API it models.

---

## Questions?

If you're blocked on setup issues (not implementation), reach out. Good luck!
