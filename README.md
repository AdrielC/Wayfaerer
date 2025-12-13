# WAYFAERER

**WAYFAERER** is a car-buying MCP server built in **Elixir**.

It helps you **search vehicle listings**, **decode VINs**, and **draft negotiation emails**, while handling concurrency, retries, rate limits, idempotency, and audit logging correctly.

WAYFAERER is **client-agnostic**. Any MCP client can talk to it.

The name comes from *wayfaerer* (archaic):
a traveler moving across uncertain terrain.

That’s car buying.

---

## what this is (and is not)

**This is:**
- an MCP server
- OTP-first
- job-oriented
- resilient
- opinionated
- practically useful

**This is not:**
- a Phoenix CRUD demo
- a scraper free-for-all
- a blocking tool server
- an email spam engine

---

## execution model

WAYFAERER uses a **job-first execution model**.

**Any MCP tool call that performs external I/O, may block, may fail, or would benefit from retries is executed as a job.**

Pure, fast, deterministic work may run **inline**.

### inline execution (allowed)

Inline execution is allowed only if the work is:
- CPU-only
- deterministic
- fast
- side-effect free
- has no retries or rate limits

Examples:
- argument validation
- normalization of input data
- hashing / idempotency key computation
- drafting email text from provided inputs
- reading job state from ETS

### job execution (required)

Jobs are required for:
- network calls
- scraping
- API requests
- email sending
- anything retryable
- anything rate-limited
- anything that can hang or fail externally

Rule of thumb:
> If you’d want retries, backoff, or an audit log, it’s a job.

---

## transports

WAYFAERER is transport-agnostic.

### v1: stdio
- best for local usage
- simplest integration
- supported by most MCP clients

### v2: streamable HTTP
- add later
- no changes required to job logic

---

## architecture

### supervision tree

Wayfaerer.Application
├─ Wayfaerer.McpServer
├─ Wayfaerer.JobQueue
├─ Wayfaerer.WorkerSupervisor (DynamicSupervisor)
├─ Wayfaerer.RateLimiter
└─ Wayfaerer.Store (ETS)

### job lifecycle

1. MCP tool called
2. arguments validated and normalized
3. idempotency key computed
4. job enqueued (or reused)
5. worker spawned
6. worker executes with:
   - timeout
   - retries
   - rate limiting
7. result stored
8. client polls `jobs.get`

---

## job system

### job states
- queued
- running
- done
- failed
- canceled

### retries
- max 3 attempts
- exponential backoff
- jitter
- per-job timeout (default 30s)

### idempotency
- key = hash(tool + normalized args + user)
- 5 minute window
- duplicate requests reuse the same job or cached result
- underlying work is never re-run

### audit log
Stored in ETS:
- tool name
- args hash
- timestamps
- state transitions
- error (if any)
- result hash

---

## MCP tools (v1)

### cars.search_listings

Search for available vehicles.

**Execution:** job

**Input**
```json
{
  "query": "2021 Subaru Outback",
  "zip": "84057",
  "radius_miles": 150,
  "price_max": 22000,
  "mileage_max": 90000,
  "awd_required": true
}
```

Notes:
- Uses a ListingsProvider behaviour
- v1 ships with a mock provider
- real APIs or scraping can be added later
- results are normalized into a stable internal shape

---

### cars.decode_vin

Decode a VIN into structured vehicle data.

**Execution:** job

**Input**
```json
{ "vin": "4S4BT..." }
```

Implementation:
- uses the NHTSA vPIC API
- normalizes make, model, year, trim, engine, drivetrain, etc.

---

### email.draft_haggle

Draft a negotiation or follow-up email.

**Execution:** inline

**Input**
```json
{
  "listing": { "...": "..." },
  "buyer_profile": {
    "name": "Adriel",
    "financing": "preapproved",
    "tone": "short"
  }
}
```

**Output**
```json
{
  "subject": "Question about the Outback listing",
  "body": "Hi ..."
}
```

Notes:
- draft only
- no email sending in v1
- deterministic and side-effect free

---

### jobs.get

Fetch job status and result.

**Execution:** inline

---

### jobs.cancel

Best-effort cancellation of queued or running jobs.

**Execution:** inline

---

## module layout

lib/
  wayfaerer/
    application.ex
    mcp_server.ex
    tools/
      cars.ex
      email.ex
      jobs.ex
    jobs/
      job_queue.ex
      worker.ex
      worker_supervisor.ex
      retry.ex
      rate_limiter.ex
      idempotency.ex
    providers/
      listings_provider.ex
      nhtsa_vin_provider.ex
    store/
      store.ex
      ets_store.ex

---

## configuration

### environment variables

LISTINGS_PROVIDER=mock  
VIN_PROVIDER=nhtsa  

Optional (only if email.send is added later):
SMTP_HOST  
SMTP_PORT  
SMTP_USERNAME  
SMTP_PASSWORD  
SMTP_FROM  

### defaults
- max workers: 8
- job timeout: 30s
- retries: 3
- idempotency window: 5 minutes

---

## safety principles

WAYFAERER is intentionally conservative.

If email sending is added later:
- domain allowlists
- per-recipient rate limits
- hard global caps
- draft-only mode always available
- instant disable via env var

No silent automation.
No spam.

---

## roadmap

### v1
- stdio MCP server
- ETS-backed job store
- VIN decoding (real)
- listings search (mock)
- haggle email drafting
- jobs.get / jobs.cancel

### v2
- real listings providers
- caching with TTL
- stronger normalization
- guarded email sending

### v3
- Postgres persistence
- cross-restart deduplication
- streamable HTTP transport

---

## philosophy

WAYFAERER is built on a simple belief:

LLM tools should be durable, auditable, and boring under the hood.

The magic belongs at the edges.
The core should survive crashes, retries, and bad inputs without drama.

---

## status

Early. Opinionated. Under active development.
