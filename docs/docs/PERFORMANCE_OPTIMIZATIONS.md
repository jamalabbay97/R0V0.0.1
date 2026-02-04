# Performance Optimizations

This document lists concrete, actionable optimizations to keep the app fast and
responsive for large datasets and heavy usage.

## App & UI

- **Reduce rebuilds with `Selector` and `Consumer` granularity**: split large
  widgets into smaller ones and only listen to the minimal fields needed.
- **Use `const` constructors** wherever possible to avoid unnecessary rebuilds.
- **Prefer `ListView.builder`/`SliverList`** for large lists so items are lazily
  built.
- **Cache and reuse expensive formatters** (e.g., `DateFormat`) instead of
  creating them inside list items.
- **Debounce search and filters** to avoid repeated queries on every keystroke.

## Local Data (SQLite)

- **Paginate queries** and avoid loading all reports at once.
- **Index high‑cardinality filters** (`date`, `type`, `group_name`) and keep
  queries ordered by indexed columns.
- **Batch inserts/updates** for sync operations to reduce transaction overhead.
- **Avoid large JSON blobs** in `additional_data` when possible; split into
  normalized columns or separate tables for frequently‑queried fields.

## Firestore

- **Page queries using `limit` + `startAfterDocument`** for large datasets.
- **Ensure composite indexes** exist for user‑scoped queries ordered by `date`.
- **Minimize reads** by fetching only needed documents and avoiding
  real‑time streams on very large collections unless required.

## Assets & Build Size

- **Compress images** (especially PNG/JPEG) before shipping.
- **Use `flutter_svg`** where appropriate to reduce bitmap sizes.
- **Remove unused fonts/images** to keep build size small.

## Telemetry & Profiling

- **Use Flutter DevTools** to measure frame times and memory usage.
- **Track cold start times** on real devices and optimize initialization paths.

## Validation Checklist

- [ ] List screens scroll smoothly with 10k+ reports.
- [ ] Initial app start completes in <2 seconds on mid‑range devices.
- [ ] Paged queries return within 100–200ms for common filters.
- [ ] Firestore reads are minimized (no redundant fetches).