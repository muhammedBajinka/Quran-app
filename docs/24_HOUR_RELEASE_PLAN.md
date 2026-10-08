# 24-hour Quran release repair plan

Schedule: 24 hourly runs, 00:20–23:20 Europe/London on 9 October 2026. Each run performs engineering work, not just a reminder. This is a work queue, not a promise that every task takes exactly one hour.

Repositories: `muhammedBajinka/Quran-app` and private `muhammedBajinka/quran-admin`. Shared Supabase project: `ppolqfsdbsgaocgasnrb`.

At every run inspect the oldest and newest relevant PRs and latest main CI/deployment. Repair failed or unverified previous work before advancing. Keep one active implementation PR. Complete the first unfinished task; resume it next hour if blocked. Implement, test, push and merge passing changes, then verify deployment. Use rollback-only synthetic data for destructive tests. Never claim device testing, R2 cleanup or Play approval without evidence. Record exact credential or service blockers and continue independent work.

| Hour / priority | Task | Completion evidence |
|---|---|---|
| 1 | Reports to admin | Six reasons reach admin; reporter cannot read or self-review. Passed: database reporter/admin and anonymous-session checks; app CI and web deployment. |
| 2 | Verified Media identity | Chosen @handle and backend badge appear together; unverified creators have no badge. |
| 3 | Category gestures | Both directions match tab order; vertical scrolling and sliders retain their gestures. |
| 4 | Creator navigation | Swipe left beyond For You or tap Creator/handle; pause and resume playback. |
| 5 | Feed refresh and empty states | Refresh reloads posts and badges; empty/error feeds still allow category navigation. |
| 6 | Playback and lifecycle | Check audio loading races, video completion, backgrounding and route transitions. |
| 7 | Comments and upload permissions | Defaults enabled; newly disabled permissions enforced for each post. |
| 8 | Social interactions | Check likes, follows, saves and reposts against server state and failures. |
| 9 | Uploads | Check queue, progress, retries, cancellation and media validation. |
| 10 | Drafts and editor | Check previews, edits, publish transitions and ownership. |
| 11 | Deletion and R2 cleanup | Verify synthetic owner deletion, authorization and retry-safe cleanup; no real content deletion. |
| 12 | Visibility and suspension | Verify private/follower content and suspended creators across app, admin and Worker. |
| 13 | Search | Three-column post results, creator results and correct selected-feed entry. |
| 14 | Sharing and deep links | Shared link enters the main Media feed at the selected post. |
| 15 | Downloads and offline | Visible progress, cancellation, failures, saved file and offline behavior. |
| 16 | Quran and reciters | Reading, audio, surah navigation and timestamps. |
| 17 | Memorization and progress | Persistence, resumption, reset and error handling. |
| 18 | Settings and accounts | Wide privacy layout, combined Share, login/logout and account deletion. |
| 19 | Admin workflows | Reports, verification, blocking, suspension, replies and audit history. |
| 20 | Diagnostics | Actionable plain-language errors, access control and sensitive-data filtering. |
| 21 | Accessibility and performance | Screen sizes, text scaling, labels, loading, pagination and expensive rebuilds. |
| 22 | Security regression | RLS, role changes, upload/download/delete authorization and secret exposure. |
| 23 | Play Store preparation | Current official policies, privacy and deletion URLs, signed AAB and versioning; record missing credentials/device checks. |
| 24 | Final release verification | Review oldest/newest PRs, main builds, deployment and unresolved blockers; publish an honest readiness report. |

## Current handoff

The compatibility migration for report reason labels is live. The rollback integration check passed for all six reasons, admin visibility, reporter inbox isolation and rejection of reporter self-review. Tasks 1–5 are completed in merged PR #17. Regression CI, analyzer, focused tests and main web deployment passed. Live browser confirmed chosen-handle verification, playback, swipe/tap creator entry, return/resume, rightward category navigation, empty-feed navigation and seeking without category changes. Signed Android APK and Play Store AAB run 37853851065 passed; both artifacts are available. Task 6 playback/lifecycle is now in progress on branch `fix/media-playback-lifecycle`; verify its CI and deployment before advancing. Flutter version is 1.0.1+4. No device tests have been performed. Cloudflare deployment credentials are unavailable in this session; document any Worker deploy requirement instead of claiming it deployed.

Additional audit findings to inspect in the queued tasks: the old `test/widget_test.dart` still expects the former Audio label and lacks current backend/platform initialization; replace it with a meaningful startup regression, then run the full suite. Large downloads are currently buffered in memory; consider bounded/native streaming. HTTPS automatic app opening still needs domain verification and Android device checks. Account deletion currently submits an admin request; verify actual completion and the external deletion route before Play release.
