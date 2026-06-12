# Series AV Agent Rules

This public repo does not define the full signed-runtime testing workflow.

For any native app workflow validation that touches signed account state,
backend-owned access, subscriptions, purchases, library sync, social/catalog
backend routes, deletion flows, private API access, or provider tokens, follow
the private AVALSYS guides. Do not invent a local runtime flow from this public
repo.

- `private/avalsys-suite/docs/platform/native-preview-dev-validation-guide.md`
- `private/avalsys-suite/docs/platform/native-account-identity-contract.md`
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
- keep private URLs, service identifiers, approval status, and operations
  evidence out of this public repo;
- treat Account AV provider session identity as session metadata only; product
  ownership and backend-owned state must resolve through the internal Apps AV
  account user contract.
- do not infer from Tune AV's station-logo rejection that Series AV must avoid
  TV/movie posters. Posters can be title-reference artwork when provider terms
  and release evidence allow them.
- do not use Netflix, IMDb, TVmaze, TheTVDB, Apple, station, or other
  company/platform/provider logos, availability badges, or deep links without
  separate documented rights/terms evidence.

If the private repo is unavailable, stop and say that the authoritative runbook
cannot be checked. Do not substitute a guessed local workflow.
