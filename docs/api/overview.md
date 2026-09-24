# Argyle API: overview

This is the API reference for the Argyle mock you integrate against. It follows the
shape of [Argyle's own API](https://docs.argyle.com), so your code should read like a
real Argyle integration.

## Base URL

The mock listens on `http://localhost:8080` by default (`./scripts/run-mock-server
--port <port>` to change it). Your service receives the base URL as `ARGYLE_BASE_URL`.

## Authentication

Every REST request uses HTTP Basic authentication:

```
Authorization: Basic base64(ARGYLE_API_ID:ARGYLE_API_SECRET)
```

A request without credentials is refused with `401`.

## Errors

Errors carry a JSON body with a `detail` field:

```json
{ "detail": "Authentication credentials were not provided." }
```

| Status | Meaning |
|---|---|
| `400` | The request is malformed |
| `401` | Missing or invalid credentials |
| `404` | No such resource |
| `429` | Too many requests. The response carries `Retry-After`, in seconds |
| `5xx` | A server-side failure. Retry with backoff |

## Pagination

List endpoints return paginated responses. The default `limit` is 10 and the maximum is
200; a larger value is treated as 200.

```json
{
  "next": "http://localhost:8080/paystubs?cursor=NEXT_CURSOR",
  "previous": null,
  "results": [ { "id": "018051aa-f7a9-a0db-2f38-6cfa325e9d69" } ]
}
```

`next` and `previous` are complete URLs, or `null` at either end. The cursor carries the
query you started with, including its filters.

Follow the complete URL returned in `next` or `previous`. Do not construct cursor values
or request pages in parallel.
