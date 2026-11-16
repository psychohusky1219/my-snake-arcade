public struct Cell: Hashable, Sendable {
    public var x: Int
    public var y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
}

public enum Direction: CaseIterable, Sendable {
    case up, down, left, right
    public var dx: Int { self == .left ? -1 : (self == .right ? 1 : 0) }
    public var dy: Int { self == .up ? -1 : (self == .down ? 1 : 0) }
    public func isOpposite(to other: Direction) -> Bool {
        dx == -other.dx && dy == -other.dy
    }
}

public enum FoodKind: Sendable { case apple, rat }
public struct Food: Equatable, Sendable {
    public let cell: Cell
    public let kind: FoodKind
    public var secondsRemaining: Double?
    public init(cell: Cell, kind: FoodKind, secondsRemaining: Double? = nil) {
        self.cell = cell
        self.kind = kind
        self.secondsRemaining = secondsRemaining
    }
}

public enum GamePhase: Sendable { case ready, running, paused, gameOver, won }
public enum GameEvent: Sendable { case none, moved, apple, rat, collision, won }

public struct GameRules: Sendable {
    public var ratChance: Double
    public var applesBeforeRats: Int
    public var ratLifetime: Double
    public init(ratChance: Double = 0.18, applesBeforeRats: Int = 3, ratLifetime: Double = 8) {
        self.ratChance = min(1, max(0, ratChance))
        self.applesBeforeRats = max(0, applesBeforeRats)
        self.ratLifetime = max(0.1, ratLifetime)
    }
}

/// Pure Swift, deterministic with an injected RNG, and independently testable.
public struct SnakeEngine {
    public let boardSize: Int
    public let rules: GameRules
    public private(set) var body: [Cell]
    public private(set) var direction: Direction = .right
    public private(set) var food: Food?
    public private(set) var score = ArcadeScore()
    public private(set) var applesEaten = 0
    public private(set) var ratsEaten = 0
    public private(set) var phase: GamePhase = .ready
    private var queuedTurns: [Direction] = []

    public init(boardSize: Int = 20, rules: GameRules = GameRules()) {
        precondition(boardSize >= 4 && boardSize <= 100)
        self.boardSize = boardSize
        self.rules = rules
        let mid = boardSize / 2
        body = [Cell(x: mid, y: mid), Cell(x: mid - 1, y: mid), Cell(x: mid - 2, y: mid)]
        food = Food(cell: Cell(x: (mid + 3) % boardSize, y: mid), kind: .apple)
    }

    // Internal fixture initializer used only by the portable unit tests.
    init(boardSize: Int = 20, body: [Cell], direction: Direction = .right,
         food: Food?, score: ArcadeScore = ArcadeScore(), applesEaten: Int = 0,
         phase: GamePhase = .running, rules: GameRules = GameRules()) {
        precondition(boardSize >= 4 && boardSize <= 100)
        precondition(!body.isEmpty && Set(body).count == body.count)
        precondition(body.allSatisfy { (0..<boardSize).contains($0.x) && (0..<boardSize).contains($0.y) })
        precondition(food == nil || !body.contains(food!.cell))
        self.boardSize = boardSize
        self.rules = rules
        self.body = body
        self.direction = direction
        self.food = food
        self.score = score
        self.applesEaten = applesEaten
        self.phase = phase
    }

    public var level: ArcadeScore { score.nextLevel }
    /// Same initial pace and playable speed ceiling as the previous game.
    public var movementInterval: Double { max(0.055, 0.195 / (1 + score.speedValue * 0.048)) }

    public mutating func start<R: RandomNumberGenerator>(using rng: inout R) {
        let mid = boardSize / 2
        body = [Cell(x: mid, y: mid), Cell(x: mid - 1, y: mid), Cell(x: mid - 2, y: mid)]
        direction = .right
        queuedTurns.removeAll()
        score = ArcadeScore()
        applesEaten = 0
        ratsEaten = 0
        phase = .running
        // Always start with an apple, even with unusual test rules.
        food = spawnFood(using: &rng, allowRat: false)
    }

    public mutating func pause() {
        if phase == .running { phase = .paused }
    }

    public mutating func resume() {
        if phase == .paused { phase = .running }
    }

    @discardableResult
    public mutating func turn(_ requested: Direction) -> Bool {
        guard phase == .running, queuedTurns.count < 2 else { return false }
        let previous = queuedTurns.last ?? direction
        guard requested != previous, !requested.isOpposite(to: previous) else { return false }
        queuedTurns.append(requested)
        return true
    }

    @discardableResult
    public mutating func tick<R: RandomNumberGenerator>(elapsed: Double, using rng: inout R) -> GameEvent {
        guard phase == .running else { return .none }
        // Rat time is active gameplay time; pauses/backgrounding do not consume it.
        if let current = food, current.kind == .rat, let remaining = current.secondsRemaining {
            let safeElapsed = elapsed.isFinite ? max(0, elapsed) : 0
            if remaining <= safeElapsed {
                food = Food(cell: current.cell, kind: .apple)
            } else {
                food?.secondsRemaining = remaining - safeElapsed
            }
        }
        if !queuedTurns.isEmpty { direction = queuedTurns.removeFirst() }
        let head = body[0]
        let next = Cell(x: (head.x + direction.dx + boardSize) % boardSize,
                        y: (head.y + direction.dy + boardSize) % boardSize)
        let eaten = food.flatMap { $0.cell == next ? $0 : nil }
        // Moving into the old tail is legal only when that tail vacates this tick.
        let occupiedCount = body.count - (eaten == nil ? 1 : 0)
        if body.prefix(occupiedCount).contains(next) {
            phase = .gameOver
            queuedTurns.removeAll()
            return .collision
        }
        body.insert(next, at: 0)
        guard let eaten else {
            body.removeLast()
            return .moved
        }
        if eaten.kind == .rat {
            score.multiplyByFive()
            ratsEaten += 1
        } else {
            score.addOne()
            applesEaten += 1
        }
        if body.count == boardSize * boardSize {
            food = nil
            phase = .won
            return .won
        }
        food = spawnFood(using: &rng)
        return eaten.kind == .rat ? .rat : .apple
    }

    private func spawnFood<R: RandomNumberGenerator>(using rng: inout R, allowRat: Bool = true) -> Food? {
        let occupied = Set(body)
        var free: [Cell] = []
        for y in 0..<boardSize {
            for x in 0..<boardSize {
                let cell = Cell(x: x, y: y)
                if !occupied.contains(cell) { free.append(cell) }
            }
        }
        guard !free.isEmpty else { return nil }
        let cell = free[Int.random(in: 0..<free.count, using: &rng)]
        let isRat = allowRat && applesEaten >= rules.applesBeforeRats
            && Double.random(in: 0..<1, using: &rng) < rules.ratChance
        return Food(cell: cell, kind: isRat ? .rat : .apple,
                    secondsRemaining: isRat ? rules.ratLifetime : nil)
    }
}
