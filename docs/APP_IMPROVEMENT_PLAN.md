# Quran Life improvement plan

User authorizes fixes, PR publication, merging after passing checks, and deployment. One implementation PR at a time; review oldest and newest relevant open PRs and latest main web/Android runs first. Never test deletion on real user content or expose credentials/private records.

## Current batch: settings, privacy and search
- Replace main Settings cards with full-width rows and separators.
- Expand the privacy page to describe existing accounts, public profiles, uploaded media, social activity and post deletion; remove the obsolete future-accounts paragraph and misleading account-sync promise.
- Search shows three columns of media previews, with no playback until tapped. Open the shared viewer at the selected result. Search public creator names/handles and open profiles.
- Debounce typing; retain clear loading, empty and error states.
- Verify analyzer, focused widget tests and web compilation in CI before merge; verify main web deployment afterward.

## Queue: each item becomes a focused PR after inspection
1. **Settings/account controls:** creator settings contains inert Manage content and Delete account taps. Implement Manage content navigation. Design secure account removal with storage cleanup and explicit confirmation before offering Delete account; do not fake a completed account removal. Audit auth errors, sign-out, guest recovery and profile edits.
2. **Privacy and permissions:** verify actual DB grants/RLS and saved privacy controls for likes/reposts/comments/downloads. Check private/draft media visibility and suspended profiles. Use synthetic rollback fixtures or aggregate metadata checks.
3. **Media reliability:** inspect upload retries, cancellation, drafts, preview/editor, audio/video transitions, seeking, social state and owner deletion. Worker deletion already checks ownership and deletes R2; user reports deletion works. Actual R2 object absence has not been independently verified. Cloudflare deployment requires authenticated Wrangler access; record a terminal command if unavailable.
4. **Quran and memorization:** reading/reciter selection, bookmarks, progress persistence, recording permissions/playback, downloads and offline recovery. Validate actual behavior; avoid rewriting working features.
5. **Sharing and navigation:** app/QR links with no release available, deep links, search retry and bounded results, small-screen/text-size layouts, back navigation and startup/offline errors.
6. **Build and regression coverage:** inspect latest Android APK failures/success, web deployment, outdated startup tests, meaningful repository/widget tests, and dependency/security findings. Do not claim device validation from compilation alone.
7. **Final review:** enumerate tested paths, remaining device-only checks and unresolved blockers. Pause hourly task when this finite queue is complete.

## Evidence and continuation log
- Baseline main: 5bd22e30fb4f09f918b94e8be0eddab346048e39 (PR #9).
- PR #9 added missing owner UPDATE/DELETE grants; rollback owner/wrong-user/anonymous DB checks passed. Main web deployment passed. User confirms deletion now works.
- 2026-10-08: hourly task enabled. Current batch in progress; no device tests performed. Flutter local bootstrap unavailable under automatic approval review; use GitHub CI, do not bypass the rejected network access.

Each run must append its PR/commit, checks and deployment results, next action and any blocker here. If a build fails, fix it first; if blocked, preserve enough detail for the next run. Do not start duplicate PRs or overwrite concurrent work.
