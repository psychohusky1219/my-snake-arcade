# My Snake Arcade

[Play the browser game](https://my-snake-arcade.vercel.app/) · [Download native releases](https://github.com/psychohusky1219/my-snake-arcade/releases)

The existing dependency-free browser/PWA and native Swift/SwiftUI iPhone game.
Choose Arrow Pad or the separate Touch Pad before playing. Scores and control
choices stay on the device; browser and native records remain separate.

## Gameplay

| Mode | Native grid | Browser grid | Rules |
| --- | --- | --- | --- |
| Classic | 20×20 | 24×24 | Original grid, wall wrapping, body collision ends the run. |
| Survivor | 28×28 | 34×34 | Approximately twice the original cell count; obstacle chance 5% at level 10, +5 percentage points each level, 100% at level 29 onward. |
| Speed Run | 35×35 | 42×42 | Twelve persistent pickups, frequent rats and blue bird shields; no run timer or obstacles. |
| Endless | 20×20 view | 24×24 view | Scrolling upward survival; food adds length, obstacle contacts remove length. |

Classic, Survivor and Speed Run start with three segments. Apples add one point,
one segment, one level and a small speed increment. Rats multiply current score
and current speed by five and add one segment, but do not change level. Speed
caps at 30 moves/sec. Each edition retains its original opening and apple pace.
In Classic/Survivor, rats become eligible after three apples, with an 18% chance
and an eight-second active-play lifetime. Speed Run rats are available immediately
and stay on the board until eaten.

Speed Run starts with twelve pickups: six apples, five rats and one blue bird.
Only the collected pickup is replaced; the others keep their positions and never
expire. Replacements have a 45% apple, 45% rat and 10% blue bird chance. Crowded
boards use only the available free cells. Apples and rats keep the rules above.
A blue bird is a shield pickup, with no score, growth, level or speed change.
Its shield lasts ten active-play seconds or one collision, whichever happens
first. Another bird refreshes it to ten seconds without stacking charges.
The countdown freezes while paused. A shielded collision cancels the fatal move,
uses the shield and pauses the game without losing segments. Choose a direction
on the arrow/touch pad, then Resume; a later unshielded collision is fatal.

Survivor replaces its obstacle layout on each apple level. Clear rolls remove
old obstacles; rats do not reroll. Placement avoids the snake, food, the area
around the head and its immediate forward course, and preserves connected open
paths. A crowded board may have fewer blocks when safe placement is impossible.

Endless starts with five segments at 5 moves/sec. The head stays near the lower
middle while the world moves down. Left/right maintain diagonal steering;
up/down straighten. Side edges clamp; body crossings are allowed. Every food
adds one point and exactly one segment. Apple speed gain is 0.12 moves/sec;
rat gain is 0.36, up to 30. One food spawns every four rows, with an 18% rat
chance. Short obstacle groups spawn every five rows starting at row ten.
Head contact consumes the whole horizontal obstacle group and removes exactly
one segment, so the same obstacle cannot repeatedly drain the snake. Tail
contact is harmless. Zero segments ends the run; offscreen tail still counts.

## Develop and verify

- `Web/`: static HTML, PWA manifest, service worker, icons and Vercel settings.
- `iOS/`: native Xcode project and portable engine tests; minimum iOS 16.
- `scripts/test-web.mjs`: Node tests exercising the real browser game script.
- `scripts/build-ios.sh`: engine tests and unsigned device build on macOS/Xcode.
- `.github/workflows/build-ios.yml`: existing public-repository macOS build/release.

Run `node scripts/test-web.mjs` and `swift test --package-path iOS`.
Run the device build on macOS with `bash scripts/build-ios.sh`.
The workflow publishes the actual `MySnake-unsigned.ipa`, SHA-256 checksum,
commit/build information and installation instructions to a versioned GitHub
Release after checks and compilation succeed. A successful build does not
substitute for gameplay testing on a physical iPhone.

## Install and update

Use the exact successful release's IPA with Sideloadly on Windows. Keep the
existing app installed and use the same Apple account and bundle-ID settings.
The app bundle ID remains `com.rotemmadar.mysnake`. Existing score/control keys
are retained; new modes get separate best-score keys. See
[Windows installation](docs/INSTALL-WINDOWS.md).

For the web app, open the live URL in Safari and use Add to Home Screen. Wait
for the menu's offline-ready message before relying on offline play. Browser
storage can be cleared or evicted by the browser/OS.

## Publishing and privacy

Continue using the existing GitHub repository and Vercel project. The native
workflow uses the standard public macOS runner, no signing secrets, no Actions
artifact/cache storage and no paid add-ons. Browser source is published through
the existing Vercel connection; a Git push alone is not assumed to deploy it.
No additional project, domain, membership or paid plan is needed by this update.

No ads, game telemetry, account system or remote score service is included.
The repository and browser game are public. Hosting providers may retain normal
request logs. Apple credentials belong only in the user's installation tool,
never in the repository or chat. This is not an App Store/TestFlight release.
