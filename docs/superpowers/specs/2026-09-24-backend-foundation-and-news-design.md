# Daybook backend: foundation and News — design

Date: 2026-09-24. Status: draft for owner review. Nothing is built yet.

## 1. Goal

One Python backend that every client talks to, starting with Phase 2 (News) and designed so the AI-heavy phases (Notes, Calendar, Recommendations) add features without reshaping it. The README fixes the stack: FastAPI, Postgres with pgvector, Redis, AWS.

The backend is built in two parts:

- **Foundation (B1–B5):** project, CI, database, AI layer, auth, deploy. It has no product features and can start before Phase 1 ships only with the owner's go (open item 1).
- **News (B6–B9):** RSS ingest, dedupe, enrichment, ranked feed, engagement events. This is Phase 2's server half; the iOS News tab is a separate spec.

Weather stays client-only. Open-Meteo is called from the device and the backend never proxies it.

The foundation is done when:

1. `make backend` (lint, types, tests) is green locally, in a cloud session and in GitHub Actions.
2. A signed-in test user gets `200` from `/v1/me` on the deployed staging service.
3. One AI call goes through the provider layer with its tokens and cost recorded, and the same test runs offline from a recorded response.
4. A migration applies cleanly to an empty database and to staging.

News is done when:

1. Sources are fetched on schedule with conditional GET, and a feed item appears once even when five sources carry it.
2. `/v1/news/feed` returns a ranked, cursor-paged feed that changes with the user's topic weights and forgets old signals.
3. The iOS client decodes it through a client generated from the OpenAPI document.
4. Every AI step has an eval set that runs nightly and its cost per 1,000 items is published in the README.

## 2. Decisions

| # | Decision | Reason |
|---|---|---|
| 1 | Python 3.13, `uv` for environments and the lockfile | Available in cloud sessions and CI; one tool for venv, lock and scripts |
| 2 | FastAPI + Pydantic v2, async throughout | README stack; OpenAPI comes for free and is the API contract |
| 3 | SQLAlchemy 2.0 async on `asyncpg`, Alembic migrations | Typed queries, explicit migrations reviewed as code |
| 4 | Postgres 17 + pgvector | One store for rows, vectors and the job queue |
| 5 | Background jobs in Postgres via `procrastinate` (proposed, open item 3) | Enqueue inside the same transaction as the write; no second broker to run |
| 6 | Redis for rate limits, short-lived caches and SSE fan-out only | Nothing in Redis is the source of truth; losing it loses no data |
| 7 | Layers as folders, depend downward only: `api` → `store` → `providers` → `model` | Same rule and names as iOS (`Store`, `Provider`); enforced by `import-linter` in CI |
| 8 | Constructor injection, no DI container; FastAPI `Depends` only at the `api` edge | Same rule as iOS: a test that forgets to inject must fail, not hit the network |
| 9 | All LLM calls go through an `LLMProvider` protocol; Claude is the one implementation | Mirrors `WeatherProvider`; a fake with recorded responses serves every test |
| 10 | Model per task is configuration, not code; defaults to the current Opus tier, with a cheaper tier only where evals show the quality holds | Model choice is the owner's cost decision and must be changeable without a deploy |
| 11 | Structured outputs for every AI step that returns data | Parsed and validated responses; no regex over model text |
| 12 | Prompt caching on every stable prefix; the Batch API for non-interactive work | Nightly enrichment runs at batch pricing; interactive paths stay streamed |
| 13 | A cost ledger row for every AI call; a per-user daily budget enforced before the call | AI-heavy phases need cost visible per feature and capped per user |
| 14 | REST under `/v1`, SSE for streamed AI responses, cursor pagination | Plain HTTP that every client and `URLSession` handle; no GraphQL, no WebSockets yet |
| 15 | OpenAPI is the contract; clients are generated (Swift OpenAPI Generator on iOS) | The spec is checked into git and CI fails when it drifts from the code |
| 16 | Sign in with Apple and Google; the backend verifies their ID tokens and issues its own short-lived access and refresh tokens | No password storage, no third-party auth vendor |
| 17 | AWS `eu-central-1`: ECS Fargate (api, worker), RDS Postgres, ElastiCache (Valkey), S3, Secrets Manager | Long-lived processes suit streaming and workers better than Lambda; EU data residency |
| 18 | Infrastructure as code with AWS CDK in Python (proposed, open item 4) | One language for the backend and its infra |
| 19 | Deploy from GitHub Actions through OIDC; a `production` environment with the owner as required reviewer | No long-lived AWS keys anywhere; same gate as the `testflight` environment |
| 20 | pytest with a real Postgres; no SQLite stand-in | pgvector, `jsonb` and the job queue must be tested for real |
| 21 | `ruff` for lint and format, `pyright` in strict mode | One fast linter; strict types catch contract drift early |
| 22 | Public RSS only; store title, link, feed summary and metadata, never scraped full text | "News without paywalls" means linking out, not republishing |

## 3. Layout

```
daybook/
├─ .github/workflows/backend.yml        lint, types, tests, OpenAPI drift on PR and develop; deploy on backend-v* tags
├─ .github/workflows/backend-nightly.yml evals and live feed checks
├─ Makefile                             backend, backend-test, backend-lint, backend-openapi, backend-db
└─ backend/
   ├─ pyproject.toml, uv.lock
   ├─ alembic/                          migrations
   ├─ openapi.json                      generated, committed, checked for drift
   ├─ infra/                            CDK app
   ├─ evals/                            eval sets per AI step, golden outputs
   ├─ src/daybook/
   │    model/      pure types and rules: FeedItem, Story, Topic, TopicWeights, ranking and decay math
   │    providers/  LLMProvider + ClaudeProvider, EmbeddingProvider, FeedFetcher, IdentityVerifier (Apple, Google)
   │    store/      NewsStore, UserStore, CostLedger, repositories over SQLAlchemy
   │    jobs/       ingest, enrich, cluster, decay; thin wrappers over store calls
   │    api/        FastAPI routers, request and response schemas, auth dependency
   │    settings.py pydantic-settings, all config from the environment
   │    main.py     app factory; the one place that builds the production graph
   └─ tests/
        unit/ integration/ contract/ fixtures/ recordings/
```

The package is one distribution with folders as layers, like the iOS feature packages. A folder becomes its own package only when a second service needs it.

## 4. Components

### Foundation

- `settings.py`: every value from environment variables, validated at start-up. No config files with secrets, no defaults for anything that reaches the network.
- `main.create_app(settings)`: builds engines, providers and stores, and wires routers. Tests call it with fakes.
- `/healthz` (process alive) and `/readyz` (database and Redis reachable).
- Logging with `structlog` as JSON, a request ID on every line, OpenTelemetry traces exported to AWS. No personal data in logs.
- Errors: one problem-details shape (`type`, `title`, `status`, `detail`) for every non-2xx response.

### Auth

- `POST /v1/auth/apple`, `POST /v1/auth/google`: verify the ID token against the provider's JWKS, create or find the user, return an access token (15 minutes) and a refresh token (30 days, rotated on use, stored hashed).
- `POST /v1/auth/refresh`, `POST /v1/auth/logout`, `DELETE /v1/me` (deletes the account and its data; App Store rule).
- Families are a later concern (Calendar); the `users` table has no family column until then.

### AI layer

```python
class LLMProvider(Protocol):
    async def complete[T: BaseModel](self, task: AITask, input: Prompt, schema: type[T]) -> AIResult[T]: ...
    def stream(self, task: AITask, input: Prompt) -> AsyncIterator[AIChunk]: ...
    async def submit_batch(self, task: AITask, items: Sequence[BatchItem]) -> BatchHandle: ...
```

- `AITask` is an enum (`news_topics`, `story_summary`, later `note_structure`, `schedule_parse`). Settings map each task to a model, an effort level and a `max_tokens`. Changing a model is a config change, checked by that task's eval.
- `ClaudeProvider` uses the official `anthropic` SDK: structured outputs for data, streaming for anything user-facing, prompt caching with the system prompt and schema first, the Batch API for nightly work, and handling for the `refusal` stop reason.
- Every call writes a `ai_calls` row: task, model, input, output and cache tokens, cost, latency, user if any. `CostLedger` sums it; a call that would exceed the user's daily budget fails before it is sent.
- Prompts live in `providers/prompts/` as versioned text files; the version is stored with each call so an eval regression points at a prompt change.
- `RecordedLLMProvider` replays recorded responses keyed by task, prompt version and input hash. Unit and integration tests never reach the API. Recording is a deliberate command, like snapshot recording on iOS.
- `EmbeddingProvider` is separate because Anthropic has no embeddings endpoint (open item 2).

### News

- `sources` table seeded from a reviewed list in git. Per source: URL, language, default topics, fetch interval, ETag and Last-Modified.
- **Ingest** (`jobs/ingest`, every 15 minutes per source): conditional GET, parse with `feedparser`, canonicalise the link (strip tracking parameters, resolve known redirectors), upsert by canonical URL. A source that fails five times in a row is paused and logged.
- **Dedupe** in three passes: exact canonical URL; near-duplicate title and summary by SimHash; semantic duplicates by embedding cosine similarity above a threshold tuned on a labelled set. Duplicates join one `story`; the story keeps the earliest and the most complete item.
- **Enrich** (batched): topic tags from a fixed taxonomy through structured output, and one neutral one-line story summary written from the feed text only. Both are cached on the story and never regenerated unless the prompt version changes.
- **Rank** (`model/ranking.py`, pure): `score = freshness × quality × personal`. Freshness decays exponentially with the story's age; quality counts distinct sources and engagement across all users; personal is the dot product of the story's topics with the user's weights.
- **Preference weights with a forgetting curve**: each signal (open, dwell over 15 s, hide, "less like this") adds to a topic weight; weights decay as `w · exp(−Δt / τ)` evaluated lazily at read time, so no nightly rewrite is needed. τ is a setting, starting at 14 days.
- Endpoints: `GET /v1/news/feed?cursor=`, `POST /v1/news/events` (batched impressions, opens, dwell, hides; idempotent by client event ID), `GET /v1/news/topics`, `GET/PUT /v1/me/news-preferences`.

## 5. Data flow

```
Ingest job (per source, scheduled)
  → conditional GET → parse → canonicalise → upsert feed_items
  → enqueue dedupe in the same transaction

Dedupe job → attach to an existing story or create one → enqueue enrich if new

Nightly and on backlog: enrich batch → topics + summary per story → embeddings

Client opens News
  → GET /v1/news/feed
      candidates: stories from the last 72 h with topics and embeddings
      score with the user's decayed weights → page by cursor
  → POST /v1/news/events as the user reads
      → update topic weights (write-time add, read-time decay)
```

## 6. API contract

- FastAPI generates `openapi.json`; `make backend-openapi` writes it and CI fails when the committed file differs from the code.
- iOS uses Apple's Swift OpenAPI Generator in its own local package, so feature packages depend on generated types only through a small mapping layer, as the Rust core will later.
- Breaking changes mean `/v2`; additive changes stay in `/v1`. Enums in responses carry an unknown case on the client.
- Times are RFC 3339 in UTC; the client formats them in the user's zone.

## 7. Privacy and security

- EU hosting, EU inference region where the API supports it. The account holds an email and a provider subject ID, nothing else.
- News events are personal data: kept 180 days, then only per-topic weights remain. `DELETE /v1/me` removes everything within 30 days, including backups on their normal rotation.
- AI calls send story text, never user identity. When Notes arrives, user text is sent only for the user's own request and is never used to build shared prompts.
- The Anthropic API key lives in Secrets Manager and the GitHub environment only. Rate limits per user and per IP in Redis. CORS closed (native clients only).
- Dependencies pinned in `uv.lock`, `pip-audit` in CI, third-party actions pinned by SHA, `permissions: contents: read` at the top of every workflow.
- The feed shows the publisher's name and links to the original; no full text is stored or shown.

## 8. Testing

| Layer | Tool | Covers | Runs |
|---|---|---|---|
| Unit | pytest, hand-written fakes | ranking and decay math, canonicalisation, SimHash, token verification with fixed keys, cost calculation, budget checks | every PR |
| Integration | pytest + real Postgres with pgvector | stores, migrations, job enqueue in transactions, dedupe with embeddings from recordings | every PR |
| API contract | pytest + `httpx.AsyncClient` against `create_app` | every endpoint's status codes and schemas; OpenAPI drift | every PR |
| AI recorded | `RecordedLLMProvider` | every AI step end to end with recorded responses | every PR |
| Evals | `evals/` runner, real API | topic tagging precision and recall, summary faithfulness graded against the source text, duplicate detection on a labelled set; cost per 1,000 items | nightly, and on any prompt or model change |
| Live feeds | pytest, tag `live` | each seeded source still parses | nightly, never blocks PRs |

- Postgres for tests: GitHub Actions service container in CI; a local Postgres 17 with pgvector installed by the repo's SessionStart hook in cloud sessions, which have no Docker daemon; Docker Compose on the Mac. One `DATABASE_URL` selects it.
- Each test runs in a transaction that rolls back; tests run in parallel with `pytest-xdist`, one database per worker.
- Eval thresholds are committed; a drop below them fails the nightly run and is reported like the iOS live schema check.

## 9. CI/CD

- `backend.yml`: path-filtered to `backend/**`, the Makefile and the workflow. Runs on `ubuntu-latest` with `uv sync --locked`, `make backend-lint`, `make backend-test`, the OpenAPI drift check and `pip-audit`.
- Deploy on `backend-v*` tags (separate from iOS `v*` tags): build the image, push to ECR, run migrations as a one-off task, update the ECS services. Environment `production` with the owner as required reviewer; AWS access through OIDC.
- `backend-nightly.yml`: evals and live feeds. Needs the Anthropic key from a `nightly` environment.
- Staging is the same stack at minimum size, deployed from `develop`.

## 10. Build order

Each step starts with failing tests, is one commit per task on `develop`, and adds a row to the README build log.

| # | Step | Verify |
|---|---|---|
| B1 | Project and CI: `uv` project, layer folders, `import-linter`, ruff, pyright, pytest, `create_app`, health endpoints, settings, structured logging, `backend.yml`, SessionStart hook | green Actions run and a green cloud session |
| B2 | Database: SQLAlchemy, Alembic, pgvector, per-test transactions, job queue | migration up and down on an empty database |
| B3 | AI layer: `LLMProvider`, `ClaudeProvider`, recorded provider, cost ledger, daily budget, prompt files, eval runner skeleton | one recorded test and one live eval run |
| B4 | Auth: Apple and Google ID token verification, tokens, refresh rotation, account deletion | contract tests with fixed signing keys |
| B5 | Infra and deploy: CDK stacks, OIDC role, staging, deploy job | `/readyz` green on staging |
| B6 | News ingest: sources, fetcher with conditional GET, canonicalisation, upsert | fixture feeds, live feed check |
| B7 | Dedupe and enrichment: SimHash, embeddings, stories, topic tags, summaries, batch submission | labelled duplicate set, recorded AI tests, evals |
| B8 | Feed and events: ranking, lazy decay, feed endpoint, events endpoint, preferences | ranking table tests, contract tests |
| B9 | Client contract: committed OpenAPI, Swift client package, iOS decode test | generated client builds in `ios.yml` |

B1 to B4 run entirely in a cloud session. B5 needs the owner's AWS account steps. B9 needs a Mac for the iOS half.

## 11. Owner's manual steps

Once: create the AWS account or organisation unit, bootstrap CDK, create the GitHub OIDC provider and deploy role (B5 prints the exact commands), create the Anthropic API key and store it in the `nightly` and `production` environments and Secrets Manager, register the Sign in with Apple service ID and the Google OAuth client, approve deploy jobs.

## 12. Out of scope

Notes sync and voice (Phase 3), Health data (the backend never receives it), Calendar and families (Phase 5), recommendations beyond topic weights (Phase 6), the Rust core calling the backend (Phase 1b decides HTTP placement), web clients, admin UI, multi-region.

## 13. Open items

1. **Timing.** Start B1–B5 now, alongside Phase 1 step 5 on the Mac, or only after Phase 1 ships. The README's rule is that each phase ships before the next starts; the foundation has no user-facing feature, so it can be read as not breaking that rule, but that is the owner's call.
2. **Embeddings.** Anthropic has no embeddings endpoint. Options: a hosted embedding API (Voyage AI is the one Anthropic's docs point to), or an open-weight model run in the worker on CPU. The choice fixes the vector dimension and the pgvector index, so it is decided in B2.
3. **Job queue.** `procrastinate` on Postgres (proposed) or a Redis-based queue (`arq`, Celery). Postgres gives transactional enqueue and one less critical service; Redis queues are more common. Decide before B2.
4. **Infrastructure as code.** CDK in Python (proposed) or Terraform/OpenTofu. CDK keeps one language; Terraform is more portable and more common in job listings, which matters for a showcase.
5. **Ranking location.** Server-side ranking (this spec) or a candidate pool from the server ranked on the device by the Rust core with weights that never leave the phone. The second is better for privacy and a stronger showcase for the shared core, but it needs Phase 1b first.
6. **Model tiers per task.** The default is the current Opus tier everywhere. Moving topic tagging or summaries to a cheaper tier is a cost decision the owner makes after the B7 evals show whether quality holds.
7. **News sources.** The seeded source list and the terms of each feed are reviewed by the owner before B6 goes to staging.
