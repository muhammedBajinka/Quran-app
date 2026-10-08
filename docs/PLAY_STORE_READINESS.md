# Play Store release readiness

Release candidate: 1.0.1+4, package com.bajinka.quran.

## Verified or configured

- Existing release APK signing uses repository secrets; secrets are not committed.
- Main Android workflow now builds both a signed APK and signed AAB using the same key and Supabase configuration.
- Report reason compatibility is deployed; rollback reporter-to-admin security integration passed.
- Media badge, category gesture, seeking and identity regression tests are in PR CI.

## Still required before claiming readiness

- Confirm main Android build passes and download the signed AAB artifact.
- Inspect built manifest target SDK against current Google Play requirement (API 36 for ordinary new apps and updates as checked 8 October 2026). Build delegates targetSdk to the pinned Flutter SDK; do not assume its value.
- Run on actual Android devices: playback, upload, swipes, downloads, background/resume, permissions and account deletion.
- Verify a functional external account deletion URL, in-app initiation and the admin completion process; do not equate a pending request with completed deletion.
- Review privacy policy and Data safety answers against actual Supabase, Cloudflare, diagnostic and media handling.
- Complete applicable Play Console account verification, package registration, testing/access instructions, content rating and release checks. These depend on the developer account and are not verified from this source checkout.
- Finish the queue in 24_HOUR_RELEASE_PLAN.md, keeping failures and missing deployment credentials visible.

## Official sources checked 8 October 2026

- https://developer.android.com/google/play/requirements/target-sdk
- https://support.google.com/googleplay/android-developer/answer/13327111

This checklist records remaining evidence. It is not a claim of Play Store compliance or approval.
