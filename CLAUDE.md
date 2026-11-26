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
| `journey [<Journey>/<test>] [--no-build]` | UI journeys on `$BEGIAI_SIM` (a simulator UDID) | 900 s (one journey ~20–30 s; all 44 ~10–13 min, which can pass the limit: run them in two groups of named journeys) |
| `build` | Release, unsigned; fails if the Release app allows a sealed launch | 15 min |
| `a11y [--check]` | writes or checks `A11yID.md` | — |
| `format` | `swift-format lint --strict` on the Swift folders | — |
| `check` | format, a11y check, unit, build: run before each commit | — |
| `all` | check, then journey | — |

Areas and their unit targets and journeys: `TestPlans/areas.json`.
Device matrix (its `matrix`): the journeys run on iOS 26.3, 26.4 and 26.5 on the iPhone 17 Pro,
iOS 27.0 on the iPhone 17 Pro and Pro Max, and iOS 27.3 on the iPhone Duo, open. Older iOS 26
runtimes are not tested; the deployment target stays iOS 26.0. CI runs no journeys. Where
storekitd turns down the test session (26.3–26.5 with Xcode 27.2), the tip test skips and says why.
The sealed launch (`--sealed --reset --now <ISO time>`) works only when the Info.plist key
`BegiaiSealedLaunch` is `YES` (Debug). It pins the clock and keeps the stars in a temporary folder; `--reset` empties that folder.

## Gotcha

An `.accessibilityIdentifier` on a container replaces the identifiers of the views inside it,
so journeys stop finding them. Put identifiers on leaf views only.
