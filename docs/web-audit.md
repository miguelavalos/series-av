# Series AV Web Audit

Status: current as of 2026-06-18.

Series AV commercial web and Series AV web app were checked as part of the AV
web visual audit.

## Contract

- User-facing web content supports `en`, `es`, `fr`, `de`, and `ca`.
- AV-owned links preserve the active language.
- The interactive web app exposes a public informational `/`, requires login for
  functional product routes, and does not expose guest-mode product
  functionality in signed-out app areas.
- The app surface avoids visible lowercase `avalsys` except where legal or
  commercial context requires company naming.

## Latest Audit Result

- Commercial desktop and mobile browser QA passed.
- Web app desktop and mobile browser QA passed.
- Protected app routes require sign-in and keep `?lang` on redirects.
- The commercial Apps AV CTA was adjusted to preserve the active locale.
- Preview app legal/support/account links should use preview URLs when those
  URLs exist; production links from preview are allowed only as documented
  temporary exceptions until matching preview targets exist.
- The preview web app build no longer emits the large client chunk warning:
  vendor chunks are split for Clerk, serialization, UI, and app bootstrap while
  keeping the same public `/`, sign-in, and protected-route behavior.
- The production web app was deployed at `https://app.series-av.avalsys.com`.
  Production QA exposed app-owned CTAs and Avi/footer links that dropped
  non-English `?lang`; the app now localizes those links before shell, footer,
  sign-in, and product CTAs render.
