# WAYFAERER

OTP-first MCP server for car-buying tools. Implements a stdio transport with an ETS-backed job system featuring retries, backoff, idempotency, and rate limiting.

## Running

```
cd wayfaerer
mix run --no-halt
```

## Tools

- `cars.search_listings` (job, mock provider)
- `cars.decode_vin` (job, NHTSA vPIC HTTP call)
- `email.draft_haggle` (inline)
- `jobs.get` (inline)
- `jobs.cancel` (inline)

Jobs are enqueued through the MCP interface and can be polled via `jobs.get`. Cancellation is best-effort.
