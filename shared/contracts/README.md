# Shared Contracts

This folder is reserved for platform-neutral Series AV contracts.

Use it only when a rule or data shape must be shared beyond Apple Swift code: iOS, backend, generated clients, tests, or release tooling.

## Current Contracts

- `access-policy.json`: canonical Series AV access modes, plan tiers, capabilities, and per-mode limits. iOS validates its `SeriesAccessLimits` and `SeriesAccessCapabilities` adapter against this file.

## Entry Criteria

Add files here when at least one of these is true:

- backend and one or more clients need the same schema or enum values
- future non-Apple clients and Apple need the same fixture or generated input
- tests in multiple runtimes need the same canonical examples
- a release rule must be validated outside one app target

Avoid moving Apple-only Swift behavior here. Prefer `apps/ios/` until there is a real non-Apple consumer.
