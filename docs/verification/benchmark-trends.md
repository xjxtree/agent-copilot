# Benchmark Trends

This document records measured local performance baselines for the small set of
benchmarks that are stable enough to compare over time.

## Scope

- Record measured outputs, not guesses.
- Keep thresholds in the benchmark scripts where they already exist.
- Add new rows only after the matching benchmark or reproducible command exists.
- Treat `clone()` / `String` counts as profiling clues, not benchmark evidence.

## Current Baselines

| Date | Benchmark | Command | Dataset | Result | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-06-16 | Large catalog scan | `pnpm benchmark:10k` | 10,000 synthetic command-catalog records | `elapsed_ms=3170`, `elapsed_s=3.170`, `max_rss_mb=414.8` | Local macOS run after commands module split |
| 2026-06-16 | Task readiness | `pnpm benchmark:task-readiness` | 240 synthetic task skills, 12 iterations, 2 warmups | `p50_ms=17.97`, `p95_ms=18.53`, `max_ms=18.53`, `max_rss_mb=54.6` | Bounded readiness scan returned 8 rows, scanned 96 of 240 skills |
| 2026-06-16 | Routing confidence | `pnpm benchmark:routing` | 240 synthetic task skills, 12 iterations, 2 warmups | `p50_ms=17.55`, `p95_ms=18.11`, `max_ms=18.11`, `max_rss_mb=54.7` | Bounded route ranking returned 8 rows, scanned 96 of 240 skills |
| 2026-06-16 | Knowledge search | `pnpm benchmark:knowledge-search` | 120 synthetic task skills, 12 iterations, 2 warmups | `p50_ms=420.47`, `p95_ms=429.82`, `max_ms=429.82`, `max_rss_mb=963.8` | Query returned 25 rows from 120 indexed skills |
| 2026-06-16 | Native list model: sort by name | `pnpm benchmark:macos-list-model` | 10,000 synthetic Swift records, 80 iterations, 12 warmups | `p50_ms=5.07`, `p95_ms=5.70`, `max_ms=6.16` | Local macOS optimized Swift runner |
| 2026-06-16 | Native list model: path-fragment query | `pnpm benchmark:macos-list-model` | 10,000 synthetic Swift records, 80 iterations, 12 warmups | `p50_ms=45.68`, `p95_ms=46.91`, `max_ms=47.56` | Search-heavy list scenario |
| 2026-06-16 | Native list model: enabled filter | `pnpm benchmark:macos-list-model` | 10,000 synthetic Swift records, 80 iterations, 12 warmups | `p50_ms=5.46`, `p95_ms=5.63`, `max_ms=6.49` | Local macOS optimized Swift runner |
| 2026-06-16 | Native list model: Codex agent filter | `pnpm benchmark:macos-list-model` | 10,000 synthetic Swift records, 80 iterations, 12 warmups | `p50_ms=2.65`, `p95_ms=2.74`, `max_ms=2.78` | Local macOS optimized Swift runner |
| 2026-06-16 | Native list model: findings filter | `pnpm benchmark:macos-list-model` | 10,000 synthetic Swift records, 80 iterations, 12 warmups | `p50_ms=2.94`, `p95_ms=3.00`, `max_ms=3.33` | Local macOS optimized Swift runner |
| 2026-06-16 | Native list model: conflicts filter | `pnpm benchmark:macos-list-model` | 10,000 synthetic Swift records, 80 iterations, 12 warmups | `p50_ms=2.01`, `p95_ms=2.37`, `max_ms=2.49` | Local macOS optimized Swift runner |
| 2026-06-16 | Native list model: sort by path | `pnpm benchmark:macos-list-model` | 10,000 synthetic Swift records, 80 iterations, 12 warmups | `p50_ms=29.42`, `p95_ms=30.87`, `max_ms=39.92` | Local macOS optimized Swift runner |

## Maintenance

- Current required benchmark commands exist for large catalog scan, task readiness, routing confidence, knowledge search, and native list-model scenarios.
- Add a new row only after a reproducible command and fixture dataset exist.
- Keep benchmark commands out of `pnpm check:macos`; run them explicitly when performance-sensitive code changes.
