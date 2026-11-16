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
