# Bėgiai

An iPhone app that shows LTG Link trains running across Lithuania. Each train's position is estimated from the published timetable, not from live GPS.

> Bėgiai is an independent project. It is not made by or affiliated with LTG or LTG Link.

## What it does

- Draws every line on a muted Apple map and moves each running train along its track.
- Lists the lines in a panel over the map. You can star the lines you use; stars stay on your iPhone.
- Opens a page for each train from the map.
- Shows a station's next departures on an LED-style board.
- At night, when no train runs, it names the first train of the morning.
- Centres the map on you. It asks for your location only after you tap the button.

## Requirements

- Xcode 26 and iOS 26 or later
- Swift 6.2

## Build and run

Open `Begiai.xcodeproj`, pick the `Begiai` scheme and an iPhone simulator, and run.

The timetable ships with the app as `Begiai/timetable.json`. To rebuild it from the latest GTFS feed:

```sh
script/bundle.sh               # downloads the feed, then writes Begiai/timetable.json
script/bundle.sh --no-download # reuses the feed already downloaded
```

The `begiai-bundle` tool keeps LTG Link trips only, drops duplicate trips, flags sections that would be impossibly fast, places each stop along its track and simplifies the track shapes.

## Layout

| Path | What |
| --- | --- |
| `Begiai/` | The app: views, scenes and launch. Text lives in `Localizable.xcstrings`. |
| `BegiaiKit/` | The logic as a Swift package: models, stores, the motion engine and the `begiai-bundle` tool. |
| `BegiaiUITests/` | UI journeys, driven through screen helpers in `Support/Screens/`. |
| `Begiai/A11yID.swift` | The accessibility identifier registry. `A11yID.md` is generated from it. |
| `TestPlans/` | The test plan and `areas.json`, which maps each area to its unit targets and journeys. |
| `script/` | `test.sh` for tests and `bundle.sh` for the timetable. |

## Tests

`script/test.sh <lane>` is the only way to run tests. Each lane prints `GREEN`, or `RED` with each failure and a `rerun:` line.

| Lane | What |
| --- | --- |
| `unit [--area <id>]` | `swift test` in BegiaiKit, headless (about 1 s) |
| `journey [<Journey>/<test>] [--no-build]` | UI journeys on the simulator whose UDID is in `$BEGIAI_SIM` |
| `build` | Release build, unsigned. It fails if the Release app allows a sealed launch. |
| `a11y [--check]` | Writes or checks `A11yID.md` |
| `check` | a11y check, unit and build. Run it before each commit. |
| `all` | `check`, then `journey` |

UI journeys use a sealed launch (`--sealed --reset --now <ISO time>`) that pins the clock and keeps starred lines in a temporary folder. It works only in Debug builds.

## Data

The timetable comes from the national GTFS feed at [visimarsrutai.lt](https://www.visimarsrutai.lt/gtfs/). Train positions are interpolated from the timetable, so they show where a train should be, not where it is. Delays and cancellations are not shown.
