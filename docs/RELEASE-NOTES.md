# My Snake — four playable modes (unsigned iPhone build)

- Classic and Survivor: rats multiply the current score and speed by five without changing level. Apples advance level normally. Speed is independent of score and capped at 30 moves per second for responsiveness.
- Survivor: larger 28×28 native grid (34×34 browser). Levels 1–9 stay clear. Level 10 has a 5% obstacle chance, increasing by five percentage points each level to 100% at level 29. Each new apple level replaces the layout; rats leave it alone. Obstacle hits end the run.
- Speed Run is playable: 35×35 native grid (42×42 browser), 45% rat chance after three apples versus 18% in Classic/Survivor. Same rat score/speed rule, no timer or obstacles.
- New Endless: upward travel through a downward-scrolling world. Start with five segments; every apple or rat adds one segment and one point. Each obstacle contact removes one segment and consumes that obstacle group. Zero segments ends the run. Apples add 0.12 moves/sec; rats add 0.36, capped at 30.
- Endless left/right steer diagonally; up/down straighten. Side edges stop lateral movement, body crossings are allowed, and the camera follows the head. The length display includes the tail outside the view.
- Classic grids, saved Classic/Survivor best scores, app identity, and remembered Arrow Pad/Touch Pad choice are preserved. Each of the four modes has its own local best score. Swipes stay on the separate touch pad.
- Offline play, compact Pause/Restart, large arrows, and X-to-menu remain. No ads, game telemetry, or paid services were added.

The larger grids approximate two or three times the original total number of cells; they do not multiply each dimension. Snake segments look smaller without reducing the initial three-segment arcade snake.

**This IPA is unsigned.** Update through Sideloadly using the same Apple account and bundle-ID settings as your installed game. Keep the existing app installed to preserve its data. This release is a native Swift/SwiftUI device build, not a web wrapper or source ZIP. Physical-iPhone testing remains necessary.

Browser game: https://my-snake-arcade.vercel.app/
