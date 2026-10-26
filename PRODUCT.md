# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

Targets Android and iOS from one Flutter codebase. Confirmed with the owner: a single shared Material 3 design for both OSes, not a separate Cupertino language on iOS. The only per-OS divergence today is the page transition (Fade Forwards on Android, Cupertino slide on iOS). Treat native conventions (system back, permission flows, safe areas, limited photo access on iOS) as binding on both.

## Users

Primary: an ordinary person with thousands of photos and videos on their phone, opening the app in free moments to relive memories or find "that trip" by when it happened. They do not want to organize anything by hand. Other audiences (families or couples sharing memories, people hunting for one exact date) were offered and not confirmed.

## Product Purpose

Turns the device gallery into a visual timeline of memories: year, then month, then day, then moment. The app reads the photos and videos already on the phone and presents them as a calendar/timeline instead of a flat grid. Success is that a person finds or rediscovers a memory by time without creating albums or tagging anything.

## Positioning

Three claims a neighboring gallery app could not all truthfully copy:

- 100% local and private: no accounts, no servers, no analytics. The app stores only a metadata index. This is enforced, not just promised: CI checks that the Android manifest does not declare `INTERNET`.
- Time as the organizing structure (year, month, day, moment) rather than a flat grid.
- Automatic grouping into moments from dates; the user never creates albums.

The device gallery stays the source of truth. The app is read-only toward the user's files.

## Operating Context

- Reads the device gallery through `photo_manager`; handles full, limited, and denied permission states.
- Incremental sync into a local Drift (SQLite) index; the UI never touches the platform directly.
- Must stay responsive with very large galleries (benchmarked at ~50,000 assets).
- Main surfaces: timeline, calendar, photo/video viewer, settings.
- Must work offline by design: no external fonts or network assets.

## Capabilities and Constraints

- Spanish only for now (dates formatted without `intl`; weeks start on Monday). Adding a language means migrating to `intl`.
- Light and dark themes exist. Current identity is a warm terracotta seed color on neutral Material 3 surfaces with generous corners (see `lib/app/theme/app_theme.dart`). That is the incumbent state, not a confirmed brand commitment.
- Version 1.0.0 is functionally complete. Pending owner decisions: privacy-policy contact email and public URL, iOS signing (needs a Mac and an Apple developer account), store listings.
- The current app icon is a functional placeholder, not a brand design (decisions D59); replaceable via `assets/icon/`.
- Not yet verified on a real device.
- Not built: marking favorites from the viewer, sharing.

## Brand Commitments

- Name: "Galería de eventos". Android id `com.novadigitalsolutions.timeline_gallery`, iOS id `com.novadigitalsolutions.timelineGallery`; both are fixed once published.
- Voice: Spanish, plain and warm; copy keeps explaining that everything stays on the device.
- No further visual commitments have been made by the owner.

## Evidence on Hand

- Working app and a test suite (see `test/`), with perf benchmarks under `test/perf`.
- `docs/decisions.md` (technical decisions), `docs/privacy-policy.md`, `docs/release.md`.
- No user research, testimonials, store ratings, or usage data exist. Do not fabricate any.

## Product Principles

1. Privacy is a visible, verifiable property, not marketing copy: say what stays on the device and never imply a server.
2. The user's photos are the content; the interface recedes and never competes with a memory.
3. Time is the navigation. Every surface should help the person move through years, months, days, and moments without effort.
4. Zero setup: the app earns its value without albums, tags, or accounts.
5. Honest states: permission denied, limited access, empty, and loading are first-class and explained in plain language.

## Accessibility & Inclusion

No product-specific standard was established. Baseline expectation: respect system text scaling, dark mode, and screen-reader labels for media. The app is Spanish-only today.
