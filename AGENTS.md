# Series AV Agent Rules

Before work that touches signed runtime, backend-owned access, billing,
deletion, deployment, TestFlight/App Store, Convex, Cloudflare remote state, or
cross-app workflow behavior, run the private workspace preflight first:

```bash
bash ../../private/avalsys-suite/scripts/agent-preflight.sh --app series-av --intent <intent>
```

Read `../../private/avalsys-suite/docs/agents/workspace-guardrails.md` and every doc
printed by the preflight before executing commands. If the private repo is
unavailable, stop instead of guessing.

For local iOS/macOS builds, also follow
`../../private/avalsys-suite/docs/agents/native-cache-hygiene.md`: use
repo-local purpose-named `-derivedDataPath` directories and remove repo-local
`.DerivedData*`/`.derived-data*` caches after the task when no build is using
them.

This public repo does not define the full signed-runtime testing workflow.

For any native app workflow validation that touches signed account state,
backend-owned access, subscriptions, purchases, library sync, catalog
backend routes, deletion flows, private API access, or provider tokens, follow
the private AVALSYS guides. Do not invent a local runtime flow from this public
repo.

- `private/avalsys-suite/docs/platform/native-preview-dev-validation-guide.md`
- `private/avalsys-suite/docs/platform/native-account-identity-contract.md`
- `private/avalsys-suite/docs/platform/account-av-ios-testflight-contract.md`
- `private/avalsys-suite/docs/agents/plan-step.md` when the user says
  `usa plan-step` or asks for step-by-step plan execution.
- `private/avalsys-suite/docs/agents/plan-goal.md` when the user says
  `usa plan-goal` or asks for reviewed full-plan execution.

Mandatory rules:

- use Cloudflare preview for signed API runtime;
- use Convex cloud `dev`, not local Convex, when a native app workflow depends
  on Convex-backed state;
- do not use `wrangler dev` or another local Worker as product app backend;
- do not invent alternate runtime/testing flows when the private guide already
  defines one;
- use Infisical/Varlock-backed private tooling for config, deploy keys, and
  secret resolution;
- Account AV iOS login must match Tune AV's keychain pattern:
  `ACCOUNTAV_PUBLISHABLE_KEY`, `ACCOUNTAV_KEYCHAIN_SERVICE`, and
  `ACCOUNTAV_KEYCHAIN_ACCESS_GROUP` must be exposed through Info.plist,
  passed to Account AV, and validated by the runtime config check;
- Series AV's Release/prod runtime config check is
  `scripts/verify-ios-runtime-config.sh production`;
- before any TestFlight/App Store archive or upload, run the production
  simulator release gate from this repo after generating production config:
  `bun run ios:release:simulator`;
- keep private URLs, service identifiers, approval status, and operations
  evidence out of this public repo;
- treat Account AV provider session identity as session metadata only; product
  ownership and backend-owned state must resolve through the internal Apps AV
  account user contract.
- do not infer from Tune AV's station-logo rejection that Series AV must avoid
  TV/movie posters. Posters from approved catalog providers are allowed as
  title-reference artwork in normal app UI by default; do not require manual
  approval one title at a time.
- use fallback artwork only when a poster is missing, source/policy blocks it,
  or screenshot/release mode requires fallback.
- do not use Netflix, IMDb, TVmaze, TheTVDB, Apple, station, or other
  company/platform/provider logos, availability badges, or deep links without
  separate documented rights/terms evidence.

If the private repo is unavailable, stop and say that the authoritative runbook
cannot be checked. Do not substitute a guessed local workflow.
