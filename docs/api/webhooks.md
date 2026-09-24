# Webhooks

Argyle tells you about new and changed data with webhooks: HTTP `POST` requests to a URL
you register. The mock sends `paystubs.added`, `paystubs.updated` and
`paystubs.fully_synced` as a connected account's paystubs are synced.

## Subscribe

```
POST /webhooks
```

```json
{
  "name": "My integration",
  "url": "http://localhost:3000/webhooks/argyle",
  "secret": "your-webhook-secret",
  "events": ["paystubs.added", "paystubs.updated", "paystubs.fully_synced"]
}
```

`secret` signs every delivery to this URL. Your service receives it as
`ARGYLE_WEBHOOK_SECRET`.

## Deliveries

Each delivery is a `POST` with a JSON body:

```json
{ "event": "paystubs.added", "name": "My integration", "data": { } }
```

and an `X-Argyle-Signature` header: the lowercase hex HMAC-SHA512 of the **raw request
body**, keyed with your subscription's `secret`.

A delivery answered with `429`, `500`, `502`, `503` or `504`, or not answered within 10
seconds, is retried once, 30 seconds later.

Date fields in webhook payloads may arrive as a date (`2026-08-03`) or a datetime (`2026-08-03T00:00:00Z`).

## Payload reference

`account` and `user` are UUIDs in every payload.

### `paystubs.added`

New paystubs are available for the account.

| Field | Type |
|---|---|
| `account`, `user` | string (UUID) |
| `available_from`, `available_to` | date or datetime: the range of paystubs now available |
| `available_count` | integer |
| `added_count` | integer |
| `added_from`, `added_to` | date or datetime: the range of the paystubs just added |

### `paystubs.updated`

Existing paystubs changed.

| Field | Type |
|---|---|
| `account`, `user` | string (UUID) |
| `available_from`, `available_to` | date or datetime |
| `available_count` | integer |
| `updated_count` | integer |
| `updated_paystubs` | array of paystub IDs |
| `updated_from`, `updated_to` | date or datetime |

### `paystubs.fully_synced`

The account's paystub history is completely synced.

| Field | Type |
|---|---|
| `account`, `user` | string (UUID) |
| `available_from`, `available_to` | date or datetime |
| `available_count` | integer |

### `paystubs.partially_synced`

A first part of the account's paystub history is synced; more follows.

| Field | Type |
|---|---|
| `account`, `user` | string (UUID) |
| `available_from`, `available_to` | date or datetime |
| `available_count` | integer |
| `days_synced` | integer: how many days of history are synced so far |

## Simulating accounts (mock only)

These endpoints exist only on the mock, to make it produce traffic. They need a
subscription first.

| Endpoint | Effect |
|---|---|
| `POST /simulate/connect-seeded` | Connects the seeded account (`019b41d0-7a84-72db-beab-4f62f8e86ce4`), which matches the seeded income row, and syncs its paystubs |
| `POST /simulate/connect` | Connects a new random account and syncs its paystubs |
