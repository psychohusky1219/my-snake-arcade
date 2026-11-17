import SwiftUI

private enum ArcadeTheme {
    static let background = Color(red: 0.040, green: 0.080, blue: 0.105)
    static let board = Color(red: 0.055, green: 0.115, blue: 0.145)
    static let panel = Color(red: 0.105, green: 0.175, blue: 0.205)
    static let lime = Color(red: 0.72, green: 0.95, blue: 0.47)
    static let gold = Color(red: 1, green: 0.79, blue: 0.47)
    static let cyan = Color(red: 0.28, green: 0.88, blue: 1)
    static let secondary = Color(red: 0.62, green: 0.73, blue: 0.76)
}

@MainActor
struct SnakeRootView: View {
    @StateObject private var session = SnakeSession()
    @AppStorage("nativeSnake.controlStyle") private var controlStyleRaw = "arrows"
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            ArcadeTheme.background.ignoresSafeArea()
            if session.isGameVisible {
                SnakePlayView(session: session, useTouchPad: controlStyleRaw == "touch")
            } else {
                SnakeMenuView(session: session, controlStyleRaw: $controlStyleRaw)
            }
        }
        .tint(ArcadeTheme.lime)
        .onChange(of: scenePhase) { phase in
            if phase != .active { session.appBecameInactive() }
        }
    }
}

@MainActor
private struct SnakeMenuView: View {
    @ObservedObject var session: SnakeSession
    @Binding var controlStyleRaw: String

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                if geometry.size.width > geometry.size.height {
                    HStack(spacing: 24) {
                        preview(side: max(100, min(geometry.size.height - 36, geometry.size.width * 0.36)))
                        menuContent
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                } else {
                    VStack(spacing: 14) {
                        Spacer(minLength: 0)
                        title
                        preview(side: min(geometry.size.width - 90, max(70, min(120, geometry.size.height * 0.16))))
                        buttons
                        Spacer(minLength: 0)
                        footer
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
        }
    }

    private var title: some View {
        VStack(spacing: 9) {
            Text("YOUR PERSONAL ARCADE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(ArcadeTheme.lime)
            Text("MY SNAKE.")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("Four ways to keep moving.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ArcadeTheme.secondary)
        }
    }

    private var menuContent: some View {
        VStack(spacing: 16) {
            title
            buttons
            footer
        }
        .frame(maxWidth: 420)
    }

    private func preview(side: CGFloat) -> some View {
        SnakeBoardCanvas(engine: session.engine)
            .frame(width: max(100, side), height: max(100, side))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(ArcadeTheme.lime.opacity(0.35), lineWidth: 1))
            .accessibilityHidden(true)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            gameModeSelector
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(ArcadeTheme.gold)
                Text("\(session.selectedMode.title.uppercased()) BEST  \(session.best.compact)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Best score \(session.best.digits)")
            VStack(spacing: 8) {
                Text("CHOOSE YOUR CONTROLS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(ArcadeTheme.secondary)
                HStack(spacing: 8) {
                    controlChoice("Arrow Pad", symbol: "dpad.fill", value: "arrows")
                    controlChoice("Touch Pad", symbol: "hand.draw.fill", value: "touch")
                }
                Text(controlStyleRaw == "touch"
                     ? "Swipe on the separate pad, not the game board."
                     : "Steer with the large directional buttons.")
                    .font(.system(size: 10))
                    .foregroundStyle(ArcadeTheme.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: session.play) {
                Label(session.hasPausedGame ? "Continue game" : "Play \(session.selectedMode.title)", systemImage: "play.fill")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(ArcadeTheme.background)
                    .background(ArcadeTheme.lime, in: RoundedRectangle(cornerRadius: 17))
            }
            .buttonStyle(.plain)
            if session.hasPausedGame {
                Button("Start a new game", action: session.newGame)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.vertical, 6)
            }
            Text(session.selectedMode == .endless
                 ? "Food +1 point & length · 🐀 Faster speed boost"
                 : "🍎 +1 point & level · 🐀 Score & speed ×5, same level")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArcadeTheme.secondary)
                .multilineTextAlignment(.center)
            Text("Speed limit: 60 moves/sec")
                .font(.system(size: 10))
                .foregroundStyle(ArcadeTheme.secondary)
            if session.selectedMode == .speedRun {
                Text("Blue bird: shield for 10 seconds or one hit")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ArcadeTheme.cyan)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 360)
    }

    private var gameModeSelector: some View {
        VStack(spacing: 8) {
            Text("CHOOSE YOUR GAME")
                .font(.system(size: 9, weight: .bold)).tracking(1.5)
                .foregroundStyle(ArcadeTheme.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                gameChoice(.classic, symbol: "leaf.fill")
                gameChoice(.survivor, symbol: "shield.fill")
                gameChoice(.speedRun, symbol: "bolt.fill")
                gameChoice(.endless, symbol: "infinity")
            }
            Text(gameModeDescription)
                .font(.system(size: 10)).foregroundStyle(ArcadeTheme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gameModeDescription: String {
        switch session.selectedMode {
        case .classic:
            return "20×20 · Wall wrap, no obstacles. Apples advance your level; rats multiply score and speed."
        case .survivor:
            return "28×28 · Levels 1–9 are clear. Obstacle chance: 5% at level 10, then +5 percentage points per level; 100% at 29+. Blocks end the run."
        case .speedRun:
            return "35×35 · Twelve pickups: apples, rats and blue birds. They stay until eaten. Rats are available immediately; birds protect without changing score, length or level."
        case .endless:
            return "20×20 · Climb with 5 segments. Food adds 1; each block hit takes 1. Left/right steer; up/down straighten. Side edges stop sideways movement."
        }
    }

    private func gameModeSubtitle(_ mode: GameMode) -> String {
        switch mode {
        case .classic: return "20×20 · Original"
        case .survivor: return "28×28 · Obstacles 10+"
        case .speedRun: return "35×35 · Birds & more food"
        case .endless: return "20×20 · Keep climbing"
        }
    }

    private func gameChoice(_ mode: GameMode, symbol: String) -> some View {
        let selected = session.selectedMode == mode
        return Button { session.selectMode(mode) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18, weight: .bold))
                Text(mode.title).font(.system(size: 12, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(gameModeSubtitle(mode))
                    .font(.system(size: 8, weight: .medium))
            }
            .frame(maxWidth: .infinity).frame(height: 72)
            .foregroundStyle(selected ? ArcadeTheme.background : .white)
            .background(selected ? ArcadeTheme.lime : ArcadeTheme.panel,
                        in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title + ", " + gameModeSubtitle(mode))
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func controlChoice(_ title: String, symbol: String, value: String) -> some View {
        let selected = controlStyleRaw == value
        return Button { controlStyleRaw = value } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(selected ? ArcadeTheme.background : .white)
                .background(selected ? ArcadeTheme.lime : ArcadeTheme.panel,
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var footer: some View {
        VStack(spacing: 9) {
            Button {
                session.hapticsEnabled.toggle()
            } label: {
                Label(session.hapticsEnabled ? "Haptics on" : "Haptics off", systemImage: "hand.tap")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(ArcadeTheme.panel, in: Capsule())
            }
            .buttonStyle(.plain)
            Text("Offline · No ads · No account")
                .font(.system(size: 10))
                .foregroundStyle(ArcadeTheme.secondary)
        }
    }
}

@MainActor
private struct SnakePlayView: View {
    @ObservedObject var session: SnakeSession
    let useTouchPad: Bool
    @State private var confirmRestart = false

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                let side = max(100, min(geometry.size.height - 24, geometry.size.width - 320))
                let controlWidth = min(420, geometry.size.width - side - 42)
                let arrowSide = controlButtonSide(for: controlWidth, compact: true)
                HStack(spacing: 18) {
                    board(side: side)
                    VStack(spacing: 10) {
                        topBar
                        scores
                        Spacer(minLength: 0)
                        status
                        controls(buttonSide: arrowSide)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 420)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let arrowSide = controlButtonSide(for: geometry.size.width - 24, compact: false)
                let reservedHeight = 232 + arrowSide * 2 + 6
                let side = max(100, min(geometry.size.width - 28, geometry.size.height - reservedHeight))
                VStack(spacing: 10) {
                    topBar
                    scores
                    Spacer(minLength: 0)
                    board(side: side)
                    status
                    Spacer(minLength: 0)
                    controls(buttonSide: arrowSide)
                    Text(session.engine.shieldRecovery
                         ? "Choose a direction on your pad, then Resume"
                         : session.engine.mode == .endless
                         ? "← / → steer · ↑ / ↓ go straight upward"
                         : (useTouchPad ? "Swipe on the touch pad below the board" : "Use the arrow pad to steer"))
                        .font(.system(size: 10))
                        .foregroundStyle(ArcadeTheme.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Start a new game?", isPresented: $confirmRestart) {
            Button("Cancel", role: .cancel) {}
            Button("Restart", role: .destructive, action: session.newGame)
        } message: {
            Text("This run will end. Your best score stays saved.")
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MY SNAKE.")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                Text(session.engine.mode.title.uppercased() + " · IPHONE EDITION")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(ArcadeTheme.lime)
            }
            Spacer(minLength: 8)
            Button(action: session.leaveGame) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pause and return to menu")
        }
        .frame(height: 44)
    }

    private var scores: some View {
        HStack(spacing: 7) {
            metric("SCORE", value: session.engine.score, color: ArcadeTheme.lime)
            metric(session.engine.mode == .endless ? "LENGTH" : "LEVEL",
                   value: session.engine.mode == .endless
                    ? ArcadeScore(String(session.engine.body.count)) : session.engine.level,
                   color: ArcadeTheme.gold)
            metric("BEST", value: session.best, color: .white)
        }
        .frame(height: 54)
    }

    private func metric(_ name: String, value: ArcadeScore, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(name)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(ArcadeTheme.secondary)
            Text(value.compact)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 5)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(value.digits)")
    }

    private func board(side: CGFloat) -> some View {
        ZStack {
            SnakeBoardCanvas(engine: session.engine)
                .accessibilityLabel("Snake playfield. Use the separate controls to steer.")
            if session.engine.shieldRecovery {
                shieldRecoveryOverlay
            } else if session.engine.phase != .running {
                gameOverlay
            }
        }
        .frame(width: side, height: side)
        .background(ArcadeTheme.board)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ArcadeTheme.lime.opacity(0.4), lineWidth: 1.5))
    }

    private var shieldRecoveryOverlay: some View {
        VStack {
            VStack(spacing: 6) {
                Label("SHIELD USED", systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(ArcadeTheme.cyan)
                Text("Choose a direction on your pad, then Resume.")
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Resume", action: session.resume)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .foregroundStyle(ArcadeTheme.background)
                    .background(ArcadeTheme.cyan, in: RoundedRectangle(cornerRadius: 10))
                    .buttonStyle(.plain)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(ArcadeTheme.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
            .padding(6)
            Spacer(minLength: 0)
        }
    }

    private var gameOverlay: some View {
        let paused = session.engine.phase == .paused
        let won = session.engine.phase == .won
        return ZStack {
            ArcadeTheme.background.opacity(0.9)
            VStack(spacing: 12) {
                Text(paused ? "⏸" : (won ? "🏆" : "🐍"))
                    .font(.system(size: 38))
                Text(overlayTitle)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(session.engine.mode == .endless
                     ? "Score \(session.engine.score.compact) · Length \(session.engine.body.count)"
                     : "Score \(session.engine.score.compact) · Level \(session.engine.level.compact)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ArcadeTheme.secondary)
                Button {
                    if paused { session.resume() } else { session.newGame() }
                } label: {
                    Label(paused ? "Resume" : "Play again", systemImage: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .foregroundStyle(ArcadeTheme.background)
                        .background(ArcadeTheme.lime, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
    }

    private var overlayTitle: String {
        if session.engine.phase == .paused { return "PAUSED" }
        if session.engine.phase == .won { return "BOARD CLEARED!" }
        if session.engine.mode == .endless { return "NO SEGMENTS LEFT" }
        return session.engine.collisionCause == .obstacle ? "OBSTACLE HIT!" : "GAME OVER"
    }

    private var status: some View {
        HStack(spacing: 6) {
            if session.engine.mode == .speedRun, session.engine.shieldSecondsRemaining > 0 {
                Label("\(Int(ceil(session.engine.shieldSecondsRemaining)))s · 1 HIT", systemImage: "shield.fill")
                    .foregroundStyle(ArcadeTheme.cyan)
                    .accessibilityLabel("Shield active, \(Int(ceil(session.engine.shieldSecondsRemaining))) seconds or one hit remaining")
            } else if !session.lastReward.isEmpty {
                Text(session.lastReward)
                    .foregroundStyle(session.lastReward.hasPrefix("−") ? ArcadeTheme.gold : ArcadeTheme.lime)
            } else if session.engine.mode != .endless, let food = session.engine.food, food.kind == .rat {
                Text("🐀 Score/speed ×5 · \(Int(ceil(food.secondsRemaining ?? 0)))s")
                    .foregroundStyle(ArcadeTheme.gold)
            } else {
                Text(String(format: "⚡ %.1f moves/sec", session.engine.movesPerSecond))
                    .foregroundStyle(ArcadeTheme.secondary)
            }
            Spacer(minLength: 4)
            if session.engine.mode == .survivor {
                Text(session.engine.obstacles.isEmpty ? "Clear level" : "⚠ Obstacle level")
                    .foregroundStyle(session.engine.obstacles.isEmpty ? ArcadeTheme.lime : ArcadeTheme.gold)
            } else if session.engine.shieldRecovery {
                Text("Paused").foregroundStyle(ArcadeTheme.cyan)
            } else if session.engine.mode == .endless {
                Text("↑ Keep climbing").foregroundStyle(ArcadeTheme.lime)
            } else {
                Text("↔ Wrap on").foregroundStyle(ArcadeTheme.lime)
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(height: 20)
    }

    // Keep the directional pad dominant without pushing controls off small screens.
    private func controlButtonSide(for availableWidth: CGFloat, compact: Bool) -> CGFloat {
        let maximum: CGFloat = compact ? 64 : 76
        // Two 44-point utility buttons, two 8-point outer gaps, and two 6-point pad gaps.
        return min(maximum, max(44, floor((availableWidth - 116) / 3)))
    }

    private func controls(buttonSide: CGFloat) -> some View {
        return HStack(alignment: .center, spacing: 8) {
            utilityButton(session.engine.phase == .paused ? "play.fill" : "pause.fill",
                          label: session.engine.phase == .paused ? "Resume" : "Pause") {
                session.togglePause()
            }
            .disabled(session.engine.phase != .running && session.engine.phase != .paused)
            Group {
                if useTouchPad {
                    SnakeTouchPad(onTurn: session.turn, isEndless: session.engine.mode == .endless)
                        .id(session.engine.phase == .running)
                        .allowsHitTesting(session.engine.phase == .running || session.engine.shieldRecovery)
                        .frame(height: buttonSide * 2 + 6)
                } else {
                    VStack(spacing: 6) {
                        arrow(.up, symbol: "arrow.up", side: buttonSide)
                        HStack(spacing: 6) {
                            arrow(.left, symbol: "arrow.left", side: buttonSide)
                            arrow(.down, symbol: "arrow.down", side: buttonSide)
                            arrow(.right, symbol: "arrow.right", side: buttonSide)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            utilityButton("arrow.clockwise", label: "Restart") {
                if session.engine.phase == .running || session.engine.phase == .paused {
                    // Pause while the confirmation is on screen so it cannot cause a collision.
                    session.pause()
                    confirmRestart = true
                } else {
                    session.newGame()
                }
            }
        }
        .frame(height: buttonSide * 2 + 6)
    }

    private func arrow(_ direction: Direction, symbol: String, side: CGFloat) -> some View {
        Button { session.turn(direction) } label: {
            Image(systemName: symbol)
                .font(.system(size: min(34, side * 0.45), weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: side, height: side)
                .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.engine.mode == .endless && (direction == .up || direction == .down)
                            ? "Go straight upward" : "Move \(String(describing: direction))")
    }

    private func utilityButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 14, weight: .bold))
                Text(label).font(.system(size: 8, weight: .semibold))
            }
            .frame(width: 44, height: 44)
            .foregroundStyle(.white)
            .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// Only this separate control surface accepts swipe gestures. The grid is display-only.
private struct SnakeTouchPad: View {
    let onTurn: (Direction) -> Void
    let isEndless: Bool
    @GestureState private var touching = false
    @State private var previousTranslation = CGSize.zero
    @State private var fingerPosition = CGPoint.zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(ArcadeTheme.panel)
                RoundedRectangle(cornerRadius: 18)
                    .stroke(ArcadeTheme.lime.opacity(touching ? 0.9 : 0.35), lineWidth: 1.5)
                VStack(spacing: 9) {
                    Image(systemName: "arrow.up").font(.system(size: 20, weight: .bold))
                    HStack {
                        Image(systemName: "arrow.left")
                        Spacer(minLength: 4)
                        VStack(spacing: 5) {
                            Text("TOUCH PAD").font(.system(size: 10, weight: .heavy)).tracking(1)
                            Text(isEndless ? "↑ / ↓ straight" : "Swipe here").font(.system(size: 12, weight: .semibold))
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.right")
                    }
                    .padding(.horizontal, 14)
                    Image(systemName: "arrow.down").font(.system(size: 20, weight: .bold))
                }
                .foregroundStyle(ArcadeTheme.lime.opacity(0.8))
                .allowsHitTesting(false)
                if touching {
                    Circle().fill(ArcadeTheme.lime.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .position(x: min(max(12, fingerPosition.x), geometry.size.width - 12),
                                  y: min(max(12, fingerPosition.y), geometry.size.height - 12))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .gesture(DragGesture(minimumDistance: 0)
                .updating($touching) { _, active, _ in active = true }
                .onChanged { drag in steer(drag) }
                .onEnded { drag in
                    steer(drag)
                    previousTranslation = .zero
                })
            .onChange(of: touching) { active in
                if !active { previousTranslation = .zero }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isEndless
                            ? "Touch pad. Swipe left or right to steer; up or down to go straight upward."
                            : "Touch pad. Swipe here to steer. The game board does not respond to swipes.")
        .accessibilityAction(named: Text(isEndless ? "Go straight upward" : "Move up")) { onTurn(.up) }
        .accessibilityAction(named: Text(isEndless ? "Straighten" : "Move down")) { onTurn(.down) }
        .accessibilityAction(named: Text("Move left")) { onTurn(.left) }
        .accessibilityAction(named: Text("Move right")) { onTurn(.right) }
    }

    private func steer(_ drag: DragGesture.Value) {
        fingerPosition = drag.location
        let dx = drag.translation.width - previousTranslation.width
        let dy = drag.translation.height - previousTranslation.height
        guard max(abs(dx), abs(dy)) >= 13 else { return }
        onTurn(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up))
        previousTranslation = drag.translation
    }
}

private struct SnakeBoardCanvas: View {
    let engine: SnakeEngine

    var body: some View {
        Canvas { context, size in
            let cellSize = min(size.width, size.height) / CGFloat(engine.boardSize)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ArcadeTheme.board))
            var grid = Path()
            for i in 1..<engine.boardSize {
                let coordinate = CGFloat(i) * cellSize
                grid.move(to: CGPoint(x: coordinate, y: 0))
                grid.addLine(to: CGPoint(x: coordinate, y: size.height))
                grid.move(to: CGPoint(x: 0, y: coordinate))
                grid.addLine(to: CGPoint(x: size.width, y: coordinate))
            }
            context.stroke(grid, with: .color(.white.opacity(0.045)), lineWidth: 0.6)

            if engine.mode == .endless {
                var scrollingLines = Path()
                for i in 0...engine.boardSize where (i - engine.scrollRows % 5).isMultiple(of: 5) {
                    let y = CGFloat(i) * cellSize
                    scrollingLines.move(to: CGPoint(x: 0, y: y))
                    scrollingLines.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(scrollingLines, with: .color(ArcadeTheme.lime.opacity(0.14)), lineWidth: 1)
            }

            for obstacle in engine.obstacles {
                let inset = max(1, cellSize * 0.08)
                let rect = CGRect(x: CGFloat(obstacle.x) * cellSize + inset,
                                  y: CGFloat(obstacle.y) * cellSize + inset,
                                  width: cellSize - inset * 2, height: cellSize - inset * 2)
                let shape = Path(roundedRect: rect, cornerRadius: cellSize * 0.13)
                context.fill(shape, with: .color(Color(red: 0.89, green: 0.39, blue: 0.18)))
                context.stroke(shape, with: .color(ArcadeTheme.gold), lineWidth: max(1, cellSize * 0.05))
                var cross = Path()
                cross.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.28))
                cross.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.maxY - rect.height * 0.28))
                cross.move(to: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.minY + rect.height * 0.28))
                cross.addLine(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY - rect.height * 0.28))
                context.stroke(cross, with: .color(ArcadeTheme.background.opacity(0.6)), lineWidth: max(1, cellSize * 0.08))
            }

            let visibleFoods: [Food] = engine.mode == .endless ? engine.endlessFoods
                : engine.mode == .speedRun ? engine.speedRunFoods : (engine.food.map { [$0] } ?? [])
            for food in visibleFoods {
                let center = CGPoint(x: (CGFloat(food.cell.x) + 0.5) * cellSize,
                                     y: (CGFloat(food.cell.y) + 0.5) * cellSize)
                if food.kind == .rat {
                    let rect = CGRect(x: center.x - cellSize * 0.48, y: center.y - cellSize * 0.48,
                                      width: cellSize * 0.96, height: cellSize * 0.96)
                    context.fill(Path(roundedRect: rect, cornerRadius: cellSize * 0.2),
                                 with: .color(ArcadeTheme.gold.opacity(0.22)))
                    context.draw(Text("🐀").font(.system(size: cellSize * 0.94)), at: center)
                } else if food.kind == .blueBird {
                    drawBlueBird(in: context, center: center, cellSize: cellSize)
                } else {
                    let rect = CGRect(x: center.x - cellSize * 0.33, y: center.y - cellSize * 0.25,
                                      width: cellSize * 0.66, height: cellSize * 0.66)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(red: 1, green: 0.34, blue: 0.42)))
                    let leaf = CGRect(x: center.x, y: center.y - cellSize * 0.43,
                                      width: cellSize * 0.28, height: cellSize * 0.16)
                    context.fill(Path(ellipseIn: leaf), with: .color(ArcadeTheme.lime))
                }
            }

            for (index, cell) in engine.body.enumerated().reversed() {
                guard (0..<engine.boardSize).contains(cell.x), (0..<engine.boardSize).contains(cell.y) else { continue }
                let inset = max(0.7, cellSize * 0.06)
                let rect = CGRect(x: CGFloat(cell.x) * cellSize + inset,
                                  y: CGFloat(cell.y) * cellSize + inset,
                                  width: cellSize - inset * 2, height: cellSize - inset * 2)
                let color = index == 0 ? Color(red: 0.86, green: 1, blue: 0.66)
                    : (index.isMultiple(of: 2) ? ArcadeTheme.lime : Color(red: 0.49, green: 0.80, blue: 0.40))
                let segment = Path(roundedRect: rect, cornerRadius: cellSize * 0.24)
                context.fill(segment, with: .color(color))
                if engine.mode == .speedRun, engine.shieldSecondsRemaining > 0 {
                    context.stroke(segment, with: .color(ArcadeTheme.cyan), lineWidth: max(1, cellSize * 0.16))
                }
            }
            if let head = engine.body.first {
                let cx = (CGFloat(head.x) + 0.5) * cellSize
                let cy = (CGFloat(head.y) + 0.5) * cellSize
                let forwardX = CGFloat(engine.direction.dx) * cellSize * 0.21
                let forwardY = CGFloat(engine.direction.dy) * cellSize * 0.21
                let perpendicularX = CGFloat(-engine.direction.dy) * cellSize * 0.22
                let perpendicularY = CGFloat(engine.direction.dx) * cellSize * 0.22
                let radius = cellSize * 0.085
                for sign: CGFloat in [-1, 1] {
                    let rect = CGRect(x: cx + forwardX + sign * perpendicularX - radius,
                                      y: cy + forwardY + sign * perpendicularY - radius,
                                      width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(ArcadeTheme.background))
                }
            }
        }
        .drawingGroup(opaque: true)
    }

    // Draw the pickup in code so it stays visibly blue on every iPhone.
    private func drawBlueBird(in context: GraphicsContext, center: CGPoint, cellSize: CGFloat) {
        let blue = Color(red: 0.12, green: 0.56, blue: 1)
        let body = CGRect(x: center.x - cellSize * 0.32, y: center.y - cellSize * 0.12,
                          width: cellSize * 0.57, height: cellSize * 0.48)
        var tail = Path()
        tail.move(to: CGPoint(x: center.x - cellSize * 0.22, y: center.y + cellSize * 0.03))
        tail.addLine(to: CGPoint(x: center.x - cellSize * 0.48, y: center.y - cellSize * 0.16))
        tail.addLine(to: CGPoint(x: center.x - cellSize * 0.4, y: center.y + cellSize * 0.28))
        tail.closeSubpath()
        context.fill(tail, with: .color(blue))
        context.fill(Path(ellipseIn: body), with: .color(blue))
        let wing = CGRect(x: center.x - cellSize * 0.24, y: center.y - cellSize * 0.02,
                          width: cellSize * 0.31, height: cellSize * 0.24)
        context.fill(Path(ellipseIn: wing), with: .color(ArcadeTheme.cyan))
        let head = CGRect(x: center.x + cellSize * 0.02, y: center.y - cellSize * 0.35,
                          width: cellSize * 0.36, height: cellSize * 0.37)
        context.fill(Path(ellipseIn: head), with: .color(blue))
        var beak = Path()
        beak.move(to: CGPoint(x: center.x + cellSize * 0.33, y: center.y - cellSize * 0.21))
        beak.addLine(to: CGPoint(x: center.x + cellSize * 0.49, y: center.y - cellSize * 0.12))
        beak.addLine(to: CGPoint(x: center.x + cellSize * 0.33, y: center.y - cellSize * 0.07))
        beak.closeSubpath()
        context.fill(beak, with: .color(ArcadeTheme.gold))
        let eye = CGRect(x: center.x + cellSize * 0.21, y: center.y - cellSize * 0.25,
                         width: cellSize * 0.065, height: cellSize * 0.065)
        context.fill(Path(ellipseIn: eye), with: .color(.white))
    }
}
