# Argyle Paystub Sync — Take-Home Assignment

## Your Task

Implement a webhook handler that receives mock Argyle paystub events, validates them, and triggers a background job to sync paystub data to our database.

**Time estimate:** 1.5 hours

---

## What You'll Implement

| File | What to Build |
|------|---------------|
| `src/lib/argyle/webhooks.ts` | Zod schema for webhook payload validation |
| `src/app/api/webhooks/argyle/route.ts` | POST handler for incoming webhooks |
| `src/trigger/sync-argyle-paystubs.ts` | Background task to fetch & store paystubs |

Each file contains detailed requirements in comments. Read them first.

---

## Acceptance Criteria

### Webhook Handler (`route.ts`)
- [ ] Verify `X-Argyle-Signature` header (HMAC-SHA512) — return 401 if invalid
- [ ] Validate payload with your Zod schema — return 400 if invalid
- [ ] Log all events to `webhook_events` table (including failures)
- [ ] For paystub events: find income by `external_account_id`, trigger sync task
- [ ] Return 200 on success

### Background Task (`sync-argyle-paystubs.ts`)
- [ ] Fetch paystubs from Argyle API (handle pagination)
- [ ] Upsert paystubs — insert new, update existing (match by `external_id`)
- [ ] Return `{ processed: number }`

### Webhook Schema (`webhooks.ts`)
- [ ] Validate event types: `paystubs.added`, `paystubs.updated`, `paystubs.fully_synced`, `paystubs.partially_synced`
- [ ] Export schema and TypeScript type

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

## Reference Code

Explore before you start:

- `src/lib/argyle/client.ts` — Argyle API client (use this to fetch paystubs)
- `src/lib/argyle/schemas.ts` — Zod schemas for API responses
- `prisma/schema.prisma` — Database schema (`paystubs`, `incomes`, `webhook_events`)
- `src/env.ts` — Environment variables

---

## Setup

### Requirements
- Node.js **v22.19.0+** (`node -v`)
- pnpm v9+
- macOS or Linux (Windows: use WSL2)

### Environment Variables

Create `.env`:

```env
DATABASE_URL="file:./dev.db"
ARGYLE_BASE_URL="http://localhost:8080"
ARGYLE_ID="mock-id"
ARGYLE_SECRET="mock-secret"
ARGYLE_WEBHOOK_SECRET="your-webhook-secret"
TRIGGER_SECRET_KEY="<from trigger.dev dashboard>"
TRIGGER_PROJECT_ID="<from trigger.dev dashboard>"
```

Get Trigger.dev credentials at [trigger.dev](https://trigger.dev) (free account).

### Run the App

```bash
pnpm install
pnpm db:push
pnpm db:generate
pnpm dev                           # Terminal 1: Next.js app
pnpm dlx trigger.dev@latest dev    # Terminal 2: Trigger.dev worker
./scripts/run-mock-server          # Terminal 3: Argyle mock server
```

---

## Testing Your Implementation

### 1. Register your webhook

```bash
curl -X POST http://localhost:8080/webhooks \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test",
    "url": "http://localhost:3000/api/webhooks/argyle",
    "secret": "your-webhook-secret",
    "events": ["paystubs.added", "paystubs.fully_synced", "paystubs.updated"]
  }'
```

> The `secret` must match your `ARGYLE_WEBHOOK_SECRET` env var.

### 2. Trigger a test sync

```bash
curl -X POST http://localhost:8080/simulate/connect-seeded
```

This uses the pre-seeded account ID (`019b41d0-7a84-72db-beab-4f62f8e86ce4`) that matches a database income record.

### 3. Verify

Check Prisma Studio (`pnpm db:studio`) to see if paystubs were synced.

---

## Mock Server API

| Endpoint | Description |
|----------|-------------|
| `POST /webhooks` | Register webhook URL |
| `POST /simulate/connect-seeded` | Trigger webhooks for seeded account |
| `GET /paystubs?account={id}&limit={n}` | List paystubs (paginated via `next`/`previous` cursor URLs) |

The binary implements an Argyle Mock Server that simulates a payroll/paystub API with webhook functionality.
It generates fake paystub data, sends webhook events (like `paystubs.added`, `paystubs.updated`, `paystubs.fully_synced`) to a registered callback URL, and exposes REST endpoints for querying paystubs.

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

## Repository layout

```
src/
  lib/argyle/webhooks.ts              # you implement
  app/api/webhooks/argyle/route.ts    # you implement
  trigger/sync-argyle-paystubs.ts     # you implement
  lib/argyle/client.ts                # provided — the API client
  lib/argyle/schemas.ts               # provided — API response schemas
prisma/schema.prisma                  # provided — database schema
bin/
  argyle-mock-*                       # mock Argyle server (do not edit)
  latent-cli-*                        # submission CLI (do not edit)
run.sh / run.ps1                      # submission wrappers (macOS·Linux / Windows)
WRITEUP.md                            # yours
README.md
```

You may restructure however you like.

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

- [Argyle Paystubs Webhooks](https://docs.argyle.com/api-reference/paystubs-webhooks)
- [Argyle Paystubs API](https://docs.argyle.com/api-reference/paystubs)
- [Trigger.dev Docs](https://trigger.dev/docs)

---

## Questions?

If you're blocked on setup issues (not implementation), reach out. Good luck!
