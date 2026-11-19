# App Store slides: notes

The iPhone story slides of Bėgiai, made with the app-store-story-slides skill. The user
approved all six iPhone slides of run `draft-1` on 2026-11-20; they and their raw shots are
in `approved/iPhone/`, byte for byte. Only the user's word changes a file there.

## Files

- `shots.json` how each raw shot is taken; `take.sh` takes them all.
- `slides.json` how each slide is drawn; `compose.py` draws them with `Draw.swift`.
- `runs/<run>/` drafts: `shots/iPhone/` (raw shots), `iPhone/` (slides), `scratch/`
  (framed devices and specs), `sheet.png`.
- `approved/iPhone/` the approved slides (`01-see-every-train.png` …) and their raw shots
  (`01-map.png` …), by the user's word only. `runs/` is ignored by git.

## Remake

A remake needs two things that are not in the repository: the app-store-story-slides skill
(`~/.claude/skills/app-store-story-slides/scripts/`, used by `take.sh` and `compose.py`) and
Apple's iPhone 17 Pro bezel art in `~/Documents/Bezels/iPhone 17 Pro/` (Silver and Deep Blue
Portrait PNGs, from Apple Design Resources under Apple's license).


1. Make a simulator: an iPhone 17 Pro on iOS 27.2 (its screen is 1206 × 2622, the size of
   the bezel's screen and the canvas). Never use the simulators of others.
   - `xcrun simctl spawn <udid> defaults write -g AppleLocale en_US` and
     `... -g AppleLanguages -array en-US`, then shut it down and boot it again.
   - `xcrun simctl status_bar <udid> override --time 9:41 --dataNetwork wifi --wifiMode active
     --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100`
2. `BEGIAI_SIM=<udid> Store/Screenshots/take.sh <run>` takes the six shots into
   `runs/<run>/shots/iPhone` (light, then dark for slide 5, then light again).
3. `Store/Screenshots/compose.py <run> --shots Store/Screenshots/runs/<run>/shots` draws the
   slides into `runs/<run>/iPhone`. With no `--shots` it draws from `approved/`. Words narrow
   it to a slide (`03-read-a-line`) or a device.
4. Check: the skill's `check_slides.py runs/<run>/iPhone`, `check_spec.py runs/<run>/scratch/*.json`,
   `slide_sheet.py runs/<run>/sheet.png runs/<run>/iPhone`.

The drive (`BegiaiUITests/StoreShotsJourney.swift`) skips itself unless
`TEST_RUNNER_BEGIAI_SHOTS` names a folder, so the journey lane never runs it, and it is not
in `TestPlans/areas.json`.

## The fixed moment

The sealed launch with `--now 2026-11-17T15:55:00Z` (17:55 in Vilnius, a Tuesday, the
evening peak: 27 trains run) and the frozen timetable `Fixtures/timetable-20261117.json`,
the same as the journeys. The data is LTG Link's public timetable: no personal data.

## Bezels

Apple's own iPhone 17 Pro art from `~/Documents/Bezels/iPhone 17 Pro/`, cut to its opaque
box (1318 × 2717). `Draw.swift frame` puts the shot into the bezel's clear screen
(1206 × 2622 at 72, 69): no bezel tool is installed, and nothing is drawn or tinted.

- Light shots: "iPhone 17 Pro - Silver - Portrait.png".
- The dark slide (5): "iPhone 17 Pro - Deep Blue - Portrait.png". Apple makes no black
  iPhone 17 Pro; **the user chose Deep Blue on 2026-11-19.**

## The look (decided by the user, 2026-11-19)

- Six slides, in this order, with the user's headers:
  1. "See every train in Lithuania move": the map around Vilnius, the panel at half height.
  2. "Follow your train stop by stop": a train page with its stop list.
  3. "Read a line at a glance": the Line Diagram of Vilnius – Kaunas.
  4. "Know when your next train leaves": the Vilnius board, with "in N min" rows.
  5. "Easy on the eyes at night": the map in dark mode.
  6. "Made for every rider": About, with Larger markers and High contrast in view.
- One soft light-blue background (`#DDEBF7`) with dark headers (`#0E2438`).
- Canvas 1206 × 2622 (the required medium Dynamic Island row), opaque PNG.
- The callout layout; the header is bold system type at H / 28 (93.6 px) on every slide.

The two colors, `#DDEBF7` and `#0E2438`, were approved with the slides on 2026-11-20, as
were slide 1's framing, slide 3's scroll (the tab bar covers the last two tags), slide 4's
star on Vilnius, and slide 6 with Larger markers and High contrast off.
