# My Snake — Native iPhone Edition

Version 4.2 · Swift/SwiftUI · Personal use

**This is a native app source project, not a ready-to-install IPA.** The earlier
project used a WKWebView to run bundled HTML. This version replaces that layer
with a pure Swift game engine, native SwiftUI controls, and native Canvas drawing.
There are no HTML/JavaScript files, web views, hosted pages, or third-party packages.

## Install on your iPhone

Follow **OPEN-ME-FIRST.txt**. Open **MySnake.xcodeproj** on a Mac with Xcode compatible
with your phone, select your Apple signing team, connect the iPhone, and Run.
The target supports iOS 16 and later, in portrait and both landscape directions.
A current iPhone/iOS may require a newer Xcode than this minimum deployment target.

The bundle identifier is `com.rotemmadar.mysnake`. Change it if your signing
account cannot register it. No developer team, credentials, certificates, or
provisioning profiles are included. Do not share private keys or Apple passwords
in a chat. Configure signing inside Xcode.

A free Apple Personal Team is sufficient for initial personal device testing.
Its provisioning profiles expire after 7 days, so that installation needs to be
rebuilt/reinstalled. Paid Apple Developer Program membership is a separate choice,
not a prerequisite to start this personal test. Nothing has been published to the
App Store, TestFlight, GitHub, Vercel, or any other hosting service by this package.

For a Windows-only setup, a Mac-hosted build environment is still needed to compile
this Swift iOS target; signing and installation must then be configured for your
Apple account. This source ZIP alone does not perform those steps.

## Your game rules

- The snake wraps through all four edges. Touching its own body ends the game.
- Choose the separate Touch Pad or Arrow Pad before playing. Two turns can be
  buffered; direct reversal into the snake's neck is blocked.
- Each apple adds one point and one level; rats do not change level.
- After three apples, each new food has an 18% chance of being a rat instead of
  an apple in Classic and Survivor. Rats have no countdown and persist until eaten.
  Speed Run and Endless foods also have no expiry timer.
- Eating a rat multiplies the score at that instant by exactly five: 12 becomes 60.
  Repeated multipliers use exact decimal arithmetic, so they do not overflow the
  device's fixed-size integer range. Very large values are abbreviated on screen;
  accessibility labels retain the exact value.
- Classic, Survivor and Speed Run start around 5.1 moves/second. Apples add a small
  speed increment and rats multiply speed by five. Speed Run caps at 100 moves/sec;
  Classic, Survivor and Endless cap at 60. Endless starts at 5 moves/sec and keeps
  its existing food acceleration. Blue bird shields still last ten active seconds
  or one collision, whichever comes first.
- Food never appears on the snake. Filling the board wins the game.

## Native app behavior

Play enters a full-app game screen with no browser controls or scrolling page.
X pauses the current run and returns to the in-app menu; Continue resumes it.
Pause, Resume, Restart, and optional haptic feedback are included.
The app automatically pauses when a call, locking the phone, Control Center, or
switching apps makes it inactive. Returning to the app requires tapping Resume.
Restart confirmation also pauses play.

X does not terminate the iOS process. iOS Home and app-switcher gestures remain
available; this is not a kiosk or device-locking app.

Best score and the haptic preference are saved locally using UserDefaults.
The current run stays in memory while paused, but is not restored after the
operating system terminates the app. The previous web game's browser high score
is not automatically imported into the native app.

The game code has no ads, analytics, accounts, networking, or remote resources.
Normal iOS backups can include local app preferences. Apple signing/verification
is separate from offline gameplay. The privacy manifest declares local app
preferences usage (`NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1`)
and no tracking or collected data.

## What has actually been validated

- **Passed:** 18 XCTest cases for the portable Swift game engine, executed with
  Swift 6.2.1 on Linux. Includes four-way wrapping, legal/illegal turns, turn
  buffering, apple score and growth, rat 5× scoring, rat persistence, pause semantics,
  self-collision, entering a vacating tail, spawning, board completion, and large
  scores beyond machine integer range.
- **Passed:** Swift syntax parsing of the app/UI source.
- **Passed:** Xcode project, Info.plist, and privacy-manifest syntax/structure;
  source references, scheme references, asset JSON, icon files and dimensions.
- **Not done:** Apple iOS SDK compilation/type checking of SwiftUI/UIKit code,
  Simulator rendering, physical-device tests, signing, archival, or IPA export.

The engine test success is not a claim that the complete iPhone app has been
compiled or tested. Review the iPhone UI in Xcode before treating it as released.

## Project layout

```text
MySnake.xcodeproj/       iPhone app target and shared MySnake scheme
MySnake/
  MySnakeApp.swift       Native app entry point
  SnakeSession.swift     Main-thread lifecycle, timer, haptics and saved best score
  SnakeViews.swift       Native menu, game screen, board, swipes and arrow controls
  Core/ArcadeScore.swift Exact decimal scoring
  Core/SnakeEngine.swift Portable game rules and state
  Assets.xcassets/       Bundled app icon
  Info.plist            iPhone app configuration
  PrivacyInfo.xcprivacy  Privacy manifest
tools/check-macos.sh    Local Mac compile-check script; does not sign or install
Package.swift           Portable test package, not the iPhone app target
Tests/                  18 engine tests
```

From this folder, run `swift test` to rerun the engine tests.
On a Mac with Xcode selected, run `bash tools/check-macos.sh` to build the native
Simulator target without signing. That script is included but was not run here.
For actual device installation, use the Xcode project and your signing team.

## Apple references

- Personal Team limits and account setup:
  https://developer.apple.com/help/account/basics/about-your-developer-account
- Run an app on a device:
  https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html
- Enable Developer Mode:
  https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
- Required-reason privacy manifest entries:
  https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest
