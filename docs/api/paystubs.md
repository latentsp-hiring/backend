# Paystubs

## List paystubs

```
GET /paystubs
```

| Query parameter | Description |
|---|---|
| `account` | Only paystubs from this connected payroll account |
| `user` | Only paystubs belonging to this user |
| `employment` | Only paystubs from this employment |
| `from_start_date` | Only paystubs whose `paystub_date` is on or after this date (`2026-01-01` or a datetime) |
| `to_start_date` | Only paystubs whose `paystub_date` is on or before this date |
| `limit` | Page size, default 10, maximum 200 |
| `cursor` | Taken from a previous response's `next` or `previous` URL |

Results are ordered newest `paystub_date` first. See [overview.md](overview.md) for the
response envelope and pagination.

## Retrieve a paystub

```
GET /paystubs/{id}
```

Returns one paystub object, or `404` with `{"detail": "Not found."}`.

## The paystub object

Monetary amounts are **decimal strings** (`"1290.10"`), not numbers. Dates and
timestamps are ISO 8601 datetimes in UTC, except the earnings-line dates in
`gross_pay_list`, which are calendar dates (`YYYY-MM-DD`).

| Field | Type | Description |
|---|---|---|
| `id` | string (UUID) | Unique ID of the paystub |
| `account` | string (UUID) | The connected payroll account the paystub belongs to |
| `user` | string (UUID) | The user who connected the account |
| `employment` | string (UUID) | The employment the paystub was issued under |
| `employer` | string | Employer name |
| `employer_address` | object | `line1`, `line2` (nullable), `city`, `state`, `postal_code`, `country` |
| `status` | string | Paystub status |
| `paystub_date` | datetime | The pay date |
| `paystub_period` | object | `start_date`, `end_date` of the pay period |
| `currency` | string | ISO 4217 code |
| `gross_pay`, `net_pay`, `deductions`, `taxes`, `reimbursements` | decimal string | Totals for this paystub |
| `gross_pay_ytd`, `net_pay_ytd`, `deductions_ytd`, `taxes_ytd`, `hours_ytd` | decimal string | Year-to-date totals |
| `hours`, `fees` | decimal string, nullable | |
| `gross_pay_list` | array | Earnings lines: `name`, `type`, `start_date` and `end_date` (dates, `YYYY-MM-DD`), `rate`, `hours`, `amount`, `hours_ytd`, `amount_ytd` |
| `gross_pay_list_totals` | object | Totals by earnings type: `amount`, `amount_ytd`, `hours`, `hours_ytd`, `rate_implied`, `rate_implied_ytd` |
| `deduction_list` | array | `name`, `amount`, `amount_ytd`, `tax_classification` |
| `tax_list` | array | `name`, `type`, `amount`, `amount_ytd` |
| `filing_status` | array | `type`, `location` (nullable), `status` |
| `destinations` | array | Where net pay went: `reference`, `amount`, `method`, `ach_deposit_account` (`bank_name`, `routing_number`, `account_number`), `card` (`name`, `number`) |
| `payroll_document` | string, nullable | ID of the source payroll document |
| `metadata` | object, nullable | |
| `created_at`, `updated_at` | datetime | When the paystub was first stored and last changed |

The mock adds `user` to every paystub, which Argyle's own paystub object does not carry.
