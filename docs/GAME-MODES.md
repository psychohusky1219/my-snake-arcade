# My Snake — Game modes

**Classic** preserves the original rules: wall wrapping, +1 apples, score-based levels and speed, 5× rats, and no obstacles.

**Survivor** uses the same controls and scoring. Levels 1–9 are clear. Each newly reached level from 10 onward independently has a 50% chance of a new obstacle layout. The other outcome is a clear level. A rat that skips levels rolls once for the destination level. Hitting an obstacle ends the run immediately, including a hit after wrapping across the screen.

Obstacle layouts contain varied small bars, squares, L shapes and individual blocks. Each new layout replaces the previous one. The generator avoids the snake, food, nearby escape cells and seven cells along the current course, and verifies that the remaining open board is connected. Crowded boards may have fewer obstacles or none rather than force an invalid layout. A level layout remains fixed until the next level; pausing or resuming never rerolls it.

**Speed Run** is a disabled Coming soon placeholder. No timer or gameplay is implemented for it.

Both playable modes keep the large Arrow Pad / separate Touch Pad choice, smaller Pause and Restart controls, rats, wall wrapping and local high scores. Swiping the grid does nothing. Best scores are stored independently per game mode; the existing high score belongs to Classic and is preserved.

## Validation
34 native engine tests passed on Linux, including 16 Survivor-specific tests. Swift UI source passed syntax parsing, but the native update still needs the macOS/Xcode workflow and a physical-iPhone check. 20 browser test groups passed in Chromium, including 7 emulated screen sizes and 250 seeded layouts. Browser storage tests used an in-memory storage stub because network navigation was restricted in the local test runtime. Offline cache version was updated; fresh offline installation was not exercised in this runtime.
