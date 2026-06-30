# UpTime Prizes — iOS AGENTS.md
**Living reference for all iOS agents. Update after every session.**

---

## Project Summary

UpTime Prizes is a morning alarm app built around an original music catalog.
The core experience is a **three-stage alarm** that delivers one song per morning.
Revenue: one-time in-app purchases. No subscriptions. No recurring charges.

**Tagline:** "No buzz. No blare. Just melody."

---

## Version History

| Version | Date | Agent | Summary |
|---|---|---|---|
| 1.0.0 | 2026-06-30 | Android/Backend Agent | Initial iOS project scaffolded — stubs only |
| 1.1.0 | 2026-06-30 | iOS Agent (Manus) | Full implementation: alarm engine, stage audio, day progression, purchase entitlement, song seeding, AlarmView, PlayerView, DiscoverView, unit tests |

---

## Architecture

- **SwiftUI** — all UI
- **SwiftData** — local persistence (iOS 17+)
- **StoreKit 2** — in-app purchases (one-time)
- **AVFoundation** — stage-aware audio with region looping
- **UNUserNotificationCenter** — alarm scheduling

---

## Key Files

| File | Purpose |
|---|---|
| `App/UpTimePrizesApp.swift` | App entry, shared StateObjects, alarm notification listener |
| `App/ContentView.swift` | Seeds DB, wires managers, presents AlarmView via fullScreenCover |
| `Data/Models/Models.swift` | SwiftData models (Journey, Song, DemoState, Alarm) |
| `Data/Seeder/DatabaseSeeder.swift` | Seeds all journeys + songs from manifest.json |
| `Domain/AlarmEngine/AlarmEngine.swift` | UNNotification scheduling + day progression on dismiss |
| `Domain/StageCoordinator/StageCoordinator.swift` | Stage 1→2→3→Replay orchestration |
| `Platform/Audio/AudioPlayerManager.swift` | AVAudioPlayer with region seek + loop timer |
| `Platform/Billing/StoreKitManager.swift` | StoreKit 2 purchase + entitlement + restore |
| `Presentation/Alarm/AlarmView.swift` | Full-screen alarm UI |
| `Presentation/Player/PlayerView.swift` | Alarm card, time picker, song list |
| `Presentation/Discover/DiscoverView.swift` | Purchase cards, locked until day 9 |
| `Presentation/Settings/SettingsView.swift` | Journey status, debug access |
| `Presentation/Debug/DebugView.swift` | State controls + alarm trigger (DEBUG only) |
| `UpTimePrizesTests/JourneyProgressionTests.swift` | XCTest unit tests for core logic |

---

## Rules (Never Violate)

1. **BANNED WORD: "ritual"** — use "experience" or "morning experience"
2. **No subscriptions, no recurring charges** — all purchases are one-time
3. **No push notifications asking users to return**
4. **No behavioral tracking** — no advertising IDs
5. **Journey independence is sacred** — completing one journey never affects another's count
6. **Only one journey active at a time** — deactivate all others before activating a new one
7. **The Genesis never goes away** — stays with the user forever
8. **Catalyst Tracks are the exception** — immediate access, no daily progression, SPECIAL_DAY type
9. **Cross-reference findings three times** before making changes
10. **The alarm sounds** (not "fires")

---

## Journey Types

| ID | Title | Type | Days | Product ID | Price |
|---|---|---|---|---|---|
| `demo` | The Genesis | DEMO | 9 | — | Free |
| `library-a` | The Overture | LIBRARY_A | 45 | `journey_overture` | $4.99 |
| `signature` | The Cast Prelude | SIGNATURE | 8 | `journey_cast_prelude` | $2.99 |
| `special-day` | The Catalyst Tracks | SPECIAL_DAY | 5 | `journey_catalyst` | $1.99 |

---

## Playback Rules

| State | Alarm | Player Page |
|---|---|---|
| NOT_OWNED | Not available | Hidden |
| ACTIVE_IN_PROGRESS | One song per morning (alarm only) | Hidden (except Catalyst) |
| UNLOCKED_FOR_PLAYBACK | One song per morning (alarm) | Fully visible and playable |

---

## Three-Stage Alarm

| Stage | Name | Behavior |
|---|---|---|
| Stage 1 | The Invite | Loops within region until user advances or dismisses |
| Stage 2 | The Nudge | Loops within region until user advances or dismisses |
| Stage 3 | The Prize | Plays once; Replay button appears after completion |

---

## Design Tokens

| Token | Value |
|---|---|
| `brass` | `#B5985A` |
| `paper` | `#F4F1EA` |
| `ink` | `#2B1E12` |
| Font (body) | Playfair Display Regular |
| Font (headings) | Playfair Display SemiBold |

---

## CI/CD

- **Platform:** Codemagic (Mac Mini M2)
- **Trigger:** Push to `main`
- **Output:** IPA → TestFlight
- **Integration name:** `Codemagic App Manager` (already correct in codemagic.yaml)

---

## Hardware Constraint

The project owner has **no Mac and no iPhone**. All testing happens via:
1. Codemagic CI build logs
2. TestFlight (when Apple hardware is available)
3. XCTest unit tests run by CI

---

## What's Next (P3)

- [ ] Asset delivery for paid content (download Overture/Cast Prelude/Catalyst audio after purchase)
- [ ] Welcome/onboarding flow (first-launch experience)
- [ ] Background audio session hardening (foreground service equivalent)
- [ ] Journey switcher UI (select which purchased journey is active)
