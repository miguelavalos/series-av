# Series AV Web Audit

Status: current as of 2026-06-18.

Series AV commercial web and Series AV web app were checked as part of the AV
web visual audit.

## Contract

- User-facing web content supports `en`, `es`, `fr`, `de`, and `ca`.
- AV-owned links preserve the active language.
- The interactive web app is login-first and does not expose guest mode in the
  signed-out app areas.
- The app surface avoids visible lowercase `avalsys` except where legal or
  commercial context requires company naming.

## Latest Audit Result

- Commercial desktop and mobile browser QA passed.
- Web app desktop and mobile browser QA passed.
- Protected app routes require sign-in and keep `?lang` on redirects.
- The commercial Apps AV CTA was adjusted to preserve the active locale.
