# Scalability Plan

This plan outlines how to scale the app reliably as usage and data volume grow.
It assumes a Flutter client with SQLite for offline storage and Firestore for
cloud sync.

## Assumptions (Adjust as Needed)

- **Users**: 5k–50k active users
- **Daily writes**: 20–200 reports per user/day
- **Total data**: 10M+ reports over time
- **Peak concurrency**: 1k–10k concurrent sessions

## Data Modeling & Storage Strategy

### Local (SQLite)
- Keep **paged queries** for all screens that list reports.
- Use **indexes** on filterable columns (`date`, `type`, `group_name`).
- Use **batch operations** for sync to reduce IO and lock contention.

### Cloud (Firestore)
- Store reports in `reports` collection with `userId` and `date` fields.
- Use **composite indexes** on `userId + date` to support ordered, user‑scoped
  queries.
- Avoid unbounded real‑time listeners on the full `reports` collection.

## Query & Sync Strategy

1. **Client pulls data in pages** (limit 50–200).
2. **Client tracks last document** and continues from that point.
3. **Background sync** uses batch writes to reduce Firestore overhead.
4. **Conflict resolution** uses `updatedAt` timestamps (server time).

## Performance Targets

- **List load time**: < 300ms for first page (50 items).
- **Pagination fetch**: < 200ms for additional pages (on Wi‑Fi).
- **Sync batch**: < 2 seconds for 500 documents.

## Availability & Reliability

- Use **offline persistence** to keep the app functional without network.
- Maintain **graceful error handling** with user‑visible retry prompts.

## Operational & Security Controls

- Enforce **per‑user access rules** in Firestore (read/write only own docs).
- Monitor **quota and billing** (reads/writes per user).
- Implement **rate limits** or backoff in the client for burst traffic.

## Rollout & Monitoring

- Use a staged rollout (10% → 25% → 100%).
- Track **crash rate**, **latency**, and **sync error rate**.
- Add structured logging for critical flows (sync, report creation).

## Load & Failure Testing

- Simulate **10k reports** locally and verify scroll performance.
- Run **Firestore stress tests** for paged queries.
- Validate behavior under **intermittent network** conditions.

## Next Steps

- Define the exact traffic & data model for your production use case.
- Add monitoring and alerting (Crashlytics / Analytics).
- Build automated load tests for Firestore queries.