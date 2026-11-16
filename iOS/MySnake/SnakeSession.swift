import SwiftUI
import UIKit

@MainActor
final class SnakeSession: ObservableObject {
    @Published private(set) var engine = SnakeEngine()
    @Published private(set) var best: ArcadeScore
    @Published private(set) var isGameVisible = false
    @Published private(set) var lastReward = ""
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "nativeSnake.haptics") }
    }

    private let defaults: UserDefaults
    private var random = SystemRandomNumberGenerator()
    private var loopTask: Task<Void, Never>?
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()
    private var rewardTicks = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        best = ArcadeScore(defaults.string(forKey: "nativeSnake.best") ?? "0")
        hapticsEnabled = defaults.object(forKey: "nativeSnake.haptics") == nil
            ? true : defaults.bool(forKey: "nativeSnake.haptics")
    }

    var hasPausedGame: Bool { engine.phase == .paused }

    func play() {
        isGameVisible = true
        if engine.phase == .paused {
            resume()
        } else {
            newGame()
        }
    }

    func newGame() {
        stopLoop()
        engine.start(using: &random)
        isGameVisible = true
        lastReward = ""
        rewardTicks = 0
        if hapticsEnabled { impact.prepare(); notification.prepare() }
        startLoop()
    }

    func turn(_ direction: Direction) {
        engine.turn(direction)
    }

    func togglePause() {
        if engine.phase == .running { pause() }
        else if engine.phase == .paused { resume() }
    }

    func pause() {
        engine.pause()
        stopLoop()
    }

    func resume() {
        guard engine.phase == .paused else { return }
        engine.resume()
        startLoop()
    }

    func leaveGame() {
        pause()
        isGameVisible = false
    }

    func appBecameInactive() {
        // A call, Control Center, locking the phone, or switching apps pauses play.
        pause()
    }

    private func startLoop() {
        stopLoop()
        UIApplication.shared.isIdleTimerDisabled = true
        loopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard self?.engine.phase == .running,
                      let interval = self?.engine.movementInterval else { return }
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch { return }
                guard !Task.isCancelled else { return }
                self?.advance(by: interval)
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func advance(by interval: Double) {
        guard engine.phase == .running else { return }
        let previousScore = engine.score
        let event = engine.tick(elapsed: interval, using: &random)
        if rewardTicks > 0 {
            rewardTicks -= 1
            if rewardTicks == 0 { lastReward = "" }
        }
        switch event {
        case .apple:
            lastReward = "+1 POINT · LEVEL \(engine.level.compact)"
            rewardTicks = 9
            if hapticsEnabled { impact.impactOccurred(intensity: 0.65) }
        case .rat:
            lastReward = "5×! \(previousScore.compact) → \(engine.score.compact)"
            rewardTicks = 20
            if hapticsEnabled { notification.notificationOccurred(.success) }
        case .collision:
            if hapticsEnabled { notification.notificationOccurred(.error) }
        case .won:
            if hapticsEnabled { notification.notificationOccurred(.success) }
        default:
            break
        }
        if engine.score > best {
            best = engine.score
            defaults.set(best.digits, forKey: "nativeSnake.best")
        }
        if engine.phase != .running { stopLoop() }
    }
}
