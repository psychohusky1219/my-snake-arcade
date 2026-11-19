# My Snake 4.3 — Faster modes and Wall Wrap

- In both editions: Classic caps at 60, Survivor at 120, Speed Run at 240 and Endless at 300 moves per second. Existing starting speeds, pickups and shields are unchanged.
- Wall Wrap is an optional start-screen setting for Classic, Survivor and Speed Run, defaulting to On. With it Off, a wall hit ends the run unless a Speed Run shield absorbs it. Endless keeps its scrolling edges.
- The app retains its established bundle ID. This is an unsigned iPhone IPA; update through the usual Sideloadly flow.

# My Snake 4.2 — Faster Speed Run and no rat countdowns

- Native Speed Run now caps at 100 moves per second. Classic, Survivor and Endless remain capped at 60. Opening speeds and acceleration rules are unchanged.
- Removed the rat expiry timer and countdown UI entirely. Classic and Survivor rats remain until eaten; Speed Run pickups and scrolling Endless food retain their existing persistence.
- Blue bird shields are unchanged: ten active-play seconds or one collision. The shield countdown and pause behavior remain intact.
- Native app version is 4.2 (bundle build 6). Saved scores, controls and bundle ID are unchanged.

**This IPA is unsigned.** Update with Sideloadly using the same Apple account and bundle-ID settings, without deleting the existing app. Physical iPhone gameplay has not been tested.

# My Snake — Double maximum speed

- Doubled the maximum snake speed from 30 to 60 moves per second in Classic, Survivor, Speed Run and Endless, in both the browser and native iPhone editions.
- Starting speeds and acceleration rules remain unchanged. Updated the speed-limit labels and cap tests.
- Existing scores, controls, shields and app identity are preserved.

**This IPA is unsigned.** Install or update through Sideloadly using the same Apple account and bundle-ID settings. Keep the existing app installed to preserve its data.

# My Snake 4.1 — Speed Run food field and blue bird shields

- Speed Run now starts with 12 pickups: six apples, five rats and one blue bird. They stay where they are until eaten, including rats; there is no food expiry timer in this mode.
- Eating a pickup replaces only that item. Replacements are 45% apples, 45% rats and 10% blue birds; crowded boards use the remaining available cells.
- Blue birds grant one shield for 10 active-play seconds or one collision, whichever happens first. A new bird refreshes the timer to 10 seconds without stacking shields. Birds do not change score, length, level or speed.
- A shielded collision cancels the fatal move, consumes the shield and pauses the game. Choose a direction with your selected pad, then Resume. No segments are lost, and the same collision cannot kill you before you have a chance to steer.
- A cyan snake highlight and countdown show when the shield is active. Pausing or backgrounding freezes its timer; restarting or changing modes clears it.
- Classic, Survivor and Endless retain their previous rules. The selected grid sizes, independent score/level/speed, saved scores, remembered controls and app identity are preserved.
- Browser and native iPhone editions both include this update. No ads, game telemetry, paid services or signing credentials were added.

**This IPA is unsigned.** Update through Sideloadly using the same Apple account and bundle-ID settings as your installed game. Keep the existing app installed to preserve its data. This is a compiled native Swift/SwiftUI iPhone app. Physical-iPhone testing remains necessary.

Browser game: https://my-snake-arcade.vercel.app/
