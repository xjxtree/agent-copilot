# Hermes Evidence Fixtures

These fixtures document local Hermes evidence only. They are not adapter implementation inputs yet.

Evidence status:

- Local `hermes-ops` docs describe a remote macmini service, not a verified local Hermes skill layout.
- The only concrete schema-like clue is cron job management under `<hermes-home>/cron/jobs.json`.
- Cron `enabled: false` is service-task evidence only and must not be treated as skill enable/disable semantics.

`service-evidence/cron-jobs.sample.json` is a minimal evidence sample for maintainer discussion. It is not a parser contract.
