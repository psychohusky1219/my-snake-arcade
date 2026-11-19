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

public enum FoodKind: Sendable { case apple, rat, blueBird }
public struct Food: Equatable, Sendable {
    public let cell: Cell
    public let kind: FoodKind
    public init(cell: Cell, kind: FoodKind) {
        self.cell = cell
        self.kind = kind
    }
}

public enum GameMode: String, CaseIterable, Sendable {
    case classic, survivor, speedRun, endless
    public var title: String {
        switch self {
        case .classic: return "Classic"
        case .survivor: return "Survivor"
        case .speedRun: return "Speed Run"
        case .endless: return "Endless"
        }
    }
    public var isPlayable: Bool { true }
    public var maximumMovesPerSecond: Double { self == .speedRun ? 100 : 60 }
    public var boardSize: Int {
        switch self { case .classic, .endless: return 20; case .survivor: return 28; case .speedRun: return 35 }
    }
}
public enum CollisionCause: Sendable { case body, obstacle }

public enum GamePhase: Sendable { case ready, running, paused, gameOver, won }
public enum GameEvent: Sendable { case none, moved, apple, rat, blueBird, shielded, damaged, collision, won }

public struct GameRules: Sendable {
    public var ratChance: Double
    public var applesBeforeRats: Int
    public var speedRunRatChance: Double
    public init(ratChance: Double = 0.18, applesBeforeRats: Int = 3, speedRunRatChance: Double = 0.45) {
        self.ratChance = min(1, max(0, ratChance))
        self.applesBeforeRats = max(0, applesBeforeRats)
        self.speedRunRatChance = min(1, max(0, speedRunRatChance))
    }
}

/// Pure Swift, deterministic with an injected RNG, and independently testable.
public struct SnakeEngine {
    public static let initialMovesPerSecond = 1 / 0.195
    public static let appleSpeedIncrement = 0.048 / 0.195
    public static let speedRunPickupTarget = 12
    public private(set) var boardSize: Int
    public let rules: GameRules
    public private(set) var body: [Cell]
    public private(set) var direction: Direction = .right
    public private(set) var food: Food?
    public private(set) var score = ArcadeScore()
    public private(set) var applesEaten = 0
    public private(set) var ratsEaten = 0
    public private(set) var movesPerSecond = SnakeEngine.initialMovesPerSecond
    public private(set) var endlessFoods: [Food] = []
    public private(set) var speedRunFoods: [Food] = []
    public private(set) var shieldSecondsRemaining = 0.0
    public private(set) var shieldRecovery = false
    public private(set) var scrollRows = 0
    public private(set) var phase: GamePhase = .ready
    public private(set) var mode: GameMode = .classic
    public private(set) var obstacles: Set<Cell> = []
    public private(set) var collisionCause: CollisionCause?
    private var queuedTurns: [Direction] = []
    private var endlessSteering = 0

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
         phase: GamePhase = .running, rules: GameRules = GameRules(),
         mode: GameMode = .classic, obstacles: Set<Cell> = [],
         movesPerSecond: Double = SnakeEngine.initialMovesPerSecond,
         endlessFoods: [Food] = [], scrollRows: Int = 0, endlessSteering: Int = 0,
         speedRunFoods: [Food] = [], shieldSecondsRemaining: Double = 0,
         shieldRecovery: Bool = false) {
        precondition(boardSize >= 4 && boardSize <= 100)
        precondition(!body.isEmpty && Set(body).count == body.count)
        precondition(body.allSatisfy { (0..<boardSize).contains($0.x) && $0.y >= 0 && (mode == .endless || $0.y < boardSize) })
        precondition(food == nil || !body.contains(food!.cell))
        self.boardSize = boardSize
        self.rules = rules
        self.body = body
        self.direction = direction
        self.food = mode == .speedRun ? nil : food
        self.score = score
        self.applesEaten = applesEaten
        self.phase = phase
        self.mode = mode
        self.obstacles = obstacles
        self.movesPerSecond = min(mode.maximumMovesPerSecond, max(0.1, movesPerSecond))
        self.endlessFoods = endlessFoods
        self.scrollRows = scrollRows
        self.endlessSteering = min(1, max(-1, endlessSteering))
        self.speedRunFoods = mode == .speedRun ? speedRunFoods : []
        self.shieldSecondsRemaining = mode == .speedRun ? max(0, min(10, shieldSecondsRemaining)) : 0
        self.shieldRecovery = mode == .speedRun && phase == .paused && shieldRecovery
    }

    public var level: ArcadeScore { ArcadeScore(String(applesEaten)).nextLevel }
    /// Score, apple-driven level and movement rate are independent.
    public var movementInterval: Double { 1 / movesPerSecond }
    public static func obstacleProbability(forLevel level: Int) -> Double {
        // Compare before subtracting to keep even extreme fixture levels safe.
        if level < 10 { return 0 }
        if level >= 29 { return 1 }
        return Double(level - 9) * 0.05
    }
    public var obstacleProbability: Double { Self.obstacleProbability(forLevel: min(applesEaten, 28) + 1) }
    public var ratChance: Double { mode == .speedRun ? rules.speedRunRatChance : rules.ratChance }

    public mutating func start<R: RandomNumberGenerator>(mode: GameMode = .classic, using rng: inout R) {
        self.mode = mode
        boardSize = mode.boardSize
        obstacles.removeAll()
        collisionCause = nil
        let mid = boardSize / 2
        body = [Cell(x: mid, y: mid), Cell(x: mid - 1, y: mid), Cell(x: mid - 2, y: mid)]
        direction = .right
        queuedTurns.removeAll()
        score = ArcadeScore()
        applesEaten = 0
        ratsEaten = 0
        movesPerSecond = Self.initialMovesPerSecond
        endlessFoods.removeAll()
        speedRunFoods.removeAll()
        shieldSecondsRemaining = 0
        shieldRecovery = false
        scrollRows = 0
        endlessSteering = 0
        phase = .running
        if mode == .endless {
            let headY = Int(Double(boardSize) * 0.65)
            body = (0..<5).map { Cell(x: mid, y: headY + $0) }
            direction = .up
            movesPerSecond = 5
            food = nil
            endlessFoods = [Food(cell: Cell(x: mid, y: headY - 4), kind: .apple)]
            return
        }
        if mode == .speedRun {
            food = nil
            let initialMix: [FoodKind] = Array(repeating: .apple, count: 6)
                + Array(repeating: .rat, count: 5) + [.blueBird]
            for kind in initialMix { addSpeedRunPickup(kind: kind, using: &rng) }
            return
        }
        // Always start with an apple, even with unusual test rules.
        food = spawnFood(using: &rng, allowRat: false)
    }

    public mutating func pause() {
        if phase == .running { phase = .paused }
    }

    public mutating func resume() {
        if phase == .paused { phase = .running; shieldRecovery = false }
    }

    @discardableResult
    public mutating func turn(_ requested: Direction) -> Bool {
        guard phase == .running || (mode == .speedRun && phase == .paused && shieldRecovery) else { return false }
        if mode == .endless {
            // Latest steering wins; up/down both restore straight upward travel.
            endlessSteering = requested.dx
            return true
        }
        guard queuedTurns.count < 2 else { return false }
        let previous = queuedTurns.last ?? direction
        guard requested != previous, !requested.isOpposite(to: previous) else { return false }
        queuedTurns.append(requested)
        return true
    }

    @discardableResult
    public mutating func tick<R: RandomNumberGenerator>(elapsed: Double, using rng: inout R) -> GameEvent {
        guard phase == .running else { return .none }
        if mode == .endless { return tickEndless(using: &rng) }
        let safeElapsed = elapsed.isFinite ? max(0, elapsed) : 0
        if mode == .speedRun {
            shieldSecondsRemaining = max(0, shieldSecondsRemaining - safeElapsed)
        }
        if !queuedTurns.isEmpty { direction = queuedTurns.removeFirst() }
        let head = body[0]
        let next = Cell(x: (head.x + direction.dx + boardSize) % boardSize,
                        y: (head.y + direction.dy + boardSize) % boardSize)
        let eaten = mode == .speedRun ? speedRunFoods.first(where: { $0.cell == next })
            : food.flatMap({ $0.cell == next ? $0 : nil })
        let grows = eaten != nil && eaten?.kind != .blueBird
        // Moving into the old tail is legal only when that tail vacates this tick.
        let occupiedCount = body.count - (grows ? 0 : 1)
        if obstacles.contains(next) || body.prefix(occupiedCount).contains(next) {
            if mode == .speedRun && shieldSecondsRemaining > 0 {
                shieldSecondsRemaining = 0
                shieldRecovery = true
                collisionCause = nil
                phase = .paused
                queuedTurns.removeAll()
                return .shielded
            }
            collisionCause = obstacles.contains(next) ? .obstacle : .body
            phase = .gameOver
            queuedTurns.removeAll()
            return .collision
        }
        body.insert(next, at: 0)
        if !grows { body.removeLast() }
        guard let eaten else {
            return .moved
        }
        switch eaten.kind {
        case .rat:
            score.multiplyByFive()
            ratsEaten += 1
            movesPerSecond = min(mode.maximumMovesPerSecond, movesPerSecond * 5)
        case .apple:
            score.addOne()
            applesEaten += 1
            movesPerSecond = min(mode.maximumMovesPerSecond, movesPerSecond + Self.appleSpeedIncrement)
        case .blueBird:
            if mode == .speedRun { shieldSecondsRemaining = 10 }
        }
        if mode == .speedRun { speedRunFoods.removeAll { $0.cell == next } }
        if body.count == boardSize * boardSize {
            food = nil
            speedRunFoods.removeAll()
            phase = .won
            return .won
        }
        if mode == .speedRun {
            // Replace only the collected item. Every untouched item keeps its cell and kind.
            addSpeedRunPickup(using: &rng)
            if speedRunFoods.isEmpty { phase = .won; return .won }
        } else {
            // Only apples advance the level. Rats preserve the current obstacle layout.
            if eaten.kind == .apple { refreshObstacles(using: &rng) }
            food = spawnFood(using: &rng)
            if food == nil { phase = .won; return .won }
        }
        switch eaten.kind { case .apple: return .apple; case .rat: return .rat; case .blueBird: return .blueBird }
    }

    /// Regenerate once per level, not per tick or per pause/resume.
    /// All open cells stay connected; the snake and nearby escape routes are protected.
    mutating func refreshObstacles<R: RandomNumberGenerator>(using rng: inout R, roll: Double? = nil) {
        obstacles.removeAll()
        guard mode == .survivor, obstacleProbability > 0,
              (roll ?? Double.random(in: 0..<1, using: &rng)) < obstacleProbability else { return }
        let head = body[0]
        var protected = Set(body)
        if let food { protected.insert(food.cell) }
        for y in 0..<boardSize { for x in 0..<boardSize {
            let dx = min(abs(x - head.x), boardSize - abs(x - head.x))
            let dy = min(abs(y - head.y), boardSize - abs(y - head.y))
            if dx + dy <= 4 { protected.insert(Cell(x: x, y: y)) }
        } }
        // Give the current course extra room at high speeds.
        for step in 1...7 {
            protected.insert(Cell(x: (head.x + direction.dx * step + boardSize * 2) % boardSize,
                                  y: (head.y + direction.dy * step + boardSize * 2) % boardSize))
        }
        let shapes: [[Cell]] = [
            [Cell(x:0,y:0), Cell(x:1,y:0), Cell(x:2,y:0)],
            [Cell(x:0,y:0), Cell(x:0,y:1), Cell(x:0,y:2)],
            [Cell(x:0,y:0), Cell(x:1,y:0), Cell(x:0,y:1), Cell(x:1,y:1)],
            [Cell(x:0,y:0), Cell(x:0,y:1), Cell(x:1,y:1)],
            [Cell(x:0,y:0)]
        ]
        let target = Int.random(in: 4...8, using: &rng)
        var groups = 0
        for _ in 0..<100 {
            if groups >= target { break }
            let shape = shapes[Int.random(in: 0..<shapes.count, using: &rng)]
            let x = Int.random(in: 0..<boardSize, using: &rng)
            let y = Int.random(in: 0..<boardSize, using: &rng)
            let cells = Set(shape.map { Cell(x: (x + $0.x) % boardSize, y: (y + $0.y) % boardSize) })
            guard cells.isDisjoint(with: protected), cells.isDisjoint(with: obstacles) else { continue }
            let proposed = obstacles.union(cells)
            // On a crowded board, fall back to a clear level rather than force a trap.
            guard boardSize * boardSize - proposed.count - body.count >= 8,
                  allOpenCellsConnected(blocked: proposed, from: head) else { continue }
            obstacles = proposed
            groups += 1
        }
    }

    private func allOpenCellsConnected(blocked: Set<Cell>, from start: Cell) -> Bool {
        var visited: Set<Cell> = [start]
        var pending = [start]
        var cursor = 0
        while cursor < pending.count {
            let here = pending[cursor]; cursor += 1
            for d in Direction.allCases {
                let next = Cell(x: (here.x + d.dx + boardSize) % boardSize,
                                y: (here.y + d.dy + boardSize) % boardSize)
                if !blocked.contains(next), visited.insert(next).inserted { pending.append(next) }
            }
        }
        return visited.count == boardSize * boardSize - blocked.count
    }

    private func spawnFood<R: RandomNumberGenerator>(using rng: inout R, allowRat: Bool = true) -> Food? {
        let occupied = Set(body).union(obstacles)
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
            && Double.random(in: 0..<1, using: &rng) < ratChance
        return Food(cell: cell, kind: isRat ? .rat : .apple)
    }

    /// Persistent Speed Run field: no eligibility gate, expiry, or relocation of other pickups.
    private mutating func addSpeedRunPickup<R: RandomNumberGenerator>(kind: FoodKind? = nil, using rng: inout R) {
        guard mode == .speedRun, speedRunFoods.count < Self.speedRunPickupTarget else { return }
        let occupied = Set(body).union(obstacles).union(speedRunFoods.map(\.cell))
        var free: [Cell] = []
        for y in 0..<boardSize {
            for x in 0..<boardSize {
                let cell = Cell(x: x, y: y)
                if !occupied.contains(cell) { free.append(cell) }
            }
        }
        guard !free.isEmpty else { return }
        let cell = free[Int.random(in: 0..<free.count, using: &rng)]
        let selectedKind: FoodKind
        if let kind { selectedKind = kind }
        else {
            let roll = Double.random(in: 0..<1, using: &rng)
            selectedKind = roll < 0.45 ? .apple : (roll < 0.9 ? .rat : .blueBird)
        }
        speedRunFoods.append(Food(cell: cell, kind: selectedKind))
    }

    /// The head stays anchored while the world and trailing body move down one row.
    /// Only head contact damages health. A contacted horizontal group is consumed.
    private mutating func tickEndless<R: RandomNumberGenerator>(using rng: inout R) -> GameEvent {
        guard let oldHead = body.first else { phase = .gameOver; return .collision }
        let next = Cell(x: min(boardSize - 1, max(0, oldHead.x + endlessSteering)), y: oldHead.y)
        scrollRows += 1
        obstacles = Set(obstacles.compactMap { cell in
            cell.y + 1 < boardSize ? Cell(x: cell.x, y: cell.y + 1) : nil
        })
        endlessFoods = endlessFoods.compactMap { item in
            let moved = Cell(x: item.cell.x, y: item.cell.y + 1)
            return moved.y < boardSize ? Food(cell: moved, kind: item.kind) : nil
        }
        let eaten = endlessFoods.first { $0.cell == next }
        let hit = obstacles.contains(next)
        body = body.map { Cell(x: $0.x, y: $0.y + 1) }
        body.insert(next, at: 0)
        if let eaten {
            endlessFoods.removeAll { $0.cell == next }
            score.addOne()
            if eaten.kind == .rat { ratsEaten += 1 } else { applesEaten += 1 }
            movesPerSecond = min(mode.maximumMovesPerSecond, movesPerSecond + (eaten.kind == .rat ? 0.36 : 0.12))
        } else {
            body.removeLast()
        }
        if hit {
            // Obstacles spawn as horizontal groups. Consume the entire contiguous group,
            // including off-head cells, so a single contact never drains multiple segments.
            var left = next.x
            var right = next.x
            while left > 0 && obstacles.contains(Cell(x: left - 1, y: next.y)) { left -= 1 }
            while right + 1 < boardSize && obstacles.contains(Cell(x: right + 1, y: next.y)) { right += 1 }
            for x in left...right { obstacles.remove(Cell(x: x, y: next.y)) }
            body.removeLast()
            if body.isEmpty {
                collisionCause = .obstacle
                phase = .gameOver
                queuedTurns.removeAll()
                return .collision
            }
        }
        spawnEndlessWorld(using: &rng)
        if hit { return .damaged }
        if let eaten { return eaten.kind == .rat ? .rat : .apple }
        return .moved
    }

    private mutating func spawnEndlessWorld<R: RandomNumberGenerator>(using rng: inout R) {
        if scrollRows.isMultiple(of: 4) {
            let free = (0..<boardSize).map { Cell(x: $0, y: 0) }.filter { cell in
                !obstacles.contains(cell) && !endlessFoods.contains(where: { $0.cell == cell })
            }
            if !free.isEmpty {
                let cell = free[Int.random(in: 0..<free.count, using: &rng)]
                let kind: FoodKind = Double.random(in: 0..<1, using: &rng) < rules.ratChance ? .rat : .apple
                endlessFoods.append(Food(cell: cell, kind: kind))
            }
        }
        if scrollRows >= 10 && scrollRows.isMultiple(of: 5) {
            let width = Int.random(in: 1...min(3, boardSize - 2), using: &rng)
            let foodCells = Set(endlessFoods.map(\.cell))
            let starts = (0...(boardSize - width)).filter { start in
                (start..<(start + width)).allSatisfy { x in
                    let cell = Cell(x: x, y: 0)
                    return !foodCells.contains(cell) && !obstacles.contains(cell)
                }
            }
            if !starts.isEmpty {
                let x = starts[Int.random(in: 0..<starts.count, using: &rng)]
                obstacles.formUnion((x..<(x + width)).map { Cell(x: $0, y: 0) })
            }
        }
    }
}
