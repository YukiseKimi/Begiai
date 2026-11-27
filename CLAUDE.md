# Bėgiai

An iPhone app (iOS 26+) that shows LTG Link trains in Lithuania, estimated from the timetable.
The plan: https://claude.ai/artifact/3RcnaRccg9rgC57r8D9Wek. The research report and the
prototypes are in `research/`, which git ignores.

## Layout

- `Begiai/` the app: views, scenes, the launch. Text lives in `Begiai/Localizable.xcstrings`.
- `BegiaiKit/` the logic package: models, stores, the motion engine. Its tests run headless.
- `BegiaiUITests/` the journeys, through screen helpers in `Support/Screens/`.
- `Begiai/A11yID.swift` the identifier registry; `A11yID.md` is generated from it.
- Change the Xcode project with `xcrun xcodeproj`, never by hand. The scheme is hand-written.

## Tests

`script/test.sh <lane>` is the one way to run tests. Each lane prints `GREEN …`, or `RED`
with each failure and a `rerun:` line.

| Lane | What | Limit |
| --- | --- | --- |
| `unit [--area <id>]` | `swift test` in BegiaiKit, headless | 90 s (tests take ~1 s) |
| `journey [<Journey>[/<test>] ...] [--no-build]` | UI journeys on `$BEGIAI_SIM` (a simulator UDID) | 900 s (one journey ~20–30 s; all 44 took up to 760 s, in two groups) |
| `build` | Release, unsigned; fails if the Release app allows a sealed launch | 15 min |
| `a11y [--check]` | writes or checks `A11yID.md` | — |
| `format` | `swift-format lint --strict` on the Swift folders | — |
| `check` | format, a11y check, unit, build: run before each commit | — |
| `all` | check, then journey | — |

Areas and their unit targets and journeys: `TestPlans/areas.json`.
The runtimes and devices the journeys run on: its `matrix`, with the Xcode in `xcode`. Run the
Duo open. Older iOS 26 runtimes are not tested; the deployment target stays iOS 26.0. CI runs
no journeys. Where storekitd does not keep the test session (26.3–26.5 with Xcode 27.2), the tip
test skips and says why, so check a tip on iOS 26 by hand before a release (on a device, or a
runtime where StoreKit testing works).
The sealed launch (`--sealed --reset --now <ISO time>`) works only when the Info.plist key
`BegiaiSealedLaunch` is `YES` (Debug). It pins the clock and keeps the stars in a temporary folder; `--reset` empties that folder.

Another session may be running journeys. `script/test.sh` then prints `BUSY test run <pid>`
and runs nothing: wait for that run (if a loop of groups started it, wait for the loop), never
stop it. To check a journey for flakiness, use `/journey-repeat`.

## Conventions

- When you offer numbered options, give each a one-line recommendation and keep the numbers
  stable, so a reply such as "push 1, drop 3" is clear.

## Gotcha

An `.accessibilityIdentifier` on a container replaces the identifiers of the views inside it,
so journeys stop finding them. Put identifiers on leaf views only.
