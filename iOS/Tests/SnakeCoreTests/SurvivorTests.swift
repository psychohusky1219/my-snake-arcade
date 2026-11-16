import XCTest
@testable import SnakeCore

private struct SurvivorRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class SurvivorTests: XCTestCase {
    private let body = [Cell(x:14,y:14), Cell(x:13,y:14), Cell(x:12,y:14)]
    private func fixture(apples: Int = 9, mode: GameMode = .survivor,
                         food: Food? = Food(cell: Cell(x:15,y:14), kind: .apple),
                         obstacles: Set<Cell> = []) -> SnakeEngine {
        SnakeEngine(boardSize: 28, body: body, food: food, score: ArcadeScore(String(apples)),
                    applesEaten: apples, rules: GameRules(ratChance: 0), mode: mode, obstacles: obstacles)
    }
    private func connected(_ game: SnakeEngine) -> Bool {
        var seen: Set<Cell> = [game.body[0]], queue = [game.body[0]]
        var i = 0
        while i < queue.count {
            let p = queue[i]; i += 1
            for d in Direction.allCases {
                let n = Cell(x:(p.x+d.dx+game.boardSize)%game.boardSize, y:(p.y+d.dy+game.boardSize)%game.boardSize)
                if !game.obstacles.contains(n), seen.insert(n).inserted { queue.append(n) }
            }
        }
        return seen.count == game.boardSize * game.boardSize - game.obstacles.count
    }
    func testFourPlayableModesAndConfirmedGridSizes() {
        XCTAssertEqual(GameMode.allCases.count, 4)
        let sizes: [(GameMode, Int)] = [(.classic,20),(.survivor,28),(.speedRun,35),(.endless,20)]
        var game = SnakeEngine(), rng = SurvivorRNG(state: 1)
        for (mode, size) in sizes {
            XCTAssertTrue(mode.isPlayable)
            game.start(mode: mode, using: &rng)
            XCTAssertEqual(game.phase, .running)
            XCTAssertEqual(game.mode, mode)
            XCTAssertEqual(game.boardSize, size)
            XCTAssertEqual(game.body.count, mode == .endless ? 5 : 3)
            XCTAssertTrue(game.obstacles.isEmpty)
        }
    }
    func testProbabilityThresholdsAndCap() {
        for level in [Int.min, 0, 1, 9] { XCTAssertEqual(SnakeEngine.obstacleProbability(forLevel: level), 0) }
        XCTAssertEqual(SnakeEngine.obstacleProbability(forLevel: 10), 0.05, accuracy: 0.000001)
        XCTAssertEqual(SnakeEngine.obstacleProbability(forLevel: 11), 0.10, accuracy: 0.000001)
        XCTAssertEqual(SnakeEngine.obstacleProbability(forLevel: 28), 0.95, accuracy: 0.000001)
        for level in [29, 30, 100, Int.max] { XCTAssertEqual(SnakeEngine.obstacleProbability(forLevel: level), 1) }
    }
    func testProbabilityRollBoundary() {
        for (roll, expected) in [(0.049999, true), (0.05, false), (0.9, false)] {
            var game = fixture(), rng = SurvivorRNG(state: 23)
            game.refreshObstacles(using: &rng, roll: roll)
            XCTAssertEqual(!game.obstacles.isEmpty, expected)
        }
    }
    func testLevelsOneThroughNineNeverHaveObstacles() {
        for apples in 0...8 {
            var game = fixture(apples: apples), rng = SurvivorRNG(state: UInt64(apples + 1))
            game.refreshObstacles(using: &rng, roll: 0)
            XCTAssertTrue(game.obstacles.isEmpty)
        }
    }
    func testAppleReachingNineIsClearAndAppleReachingTenHasFivePercentChance() {
        for apples in [7, 8] {
            var game = fixture(apples: apples), rng = SurvivorRNG(state: 23)
            XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .apple)
            XCTAssertEqual(game.level.digits, String(apples + 2))
            XCTAssertEqual(game.obstacleProbability, apples == 7 ? 0 : 0.05, accuracy: 0.000001)
            if apples == 7 { XCTAssertTrue(game.obstacles.isEmpty) }
        }
    }
    func testClassicAndSpeedRunNeverGetObstacles() {
        for mode in [GameMode.classic, .speedRun] {
            var game = fixture(apples: 1000, mode: mode), rng = SurvivorRNG(state: 99)
            game.refreshObstacles(using: &rng, roll: 0)
            XCTAssertTrue(game.obstacles.isEmpty)
        }
    }
    func testRandomRollProducesClearAndObstacleLevelsBeforeCap() {
        var clear = 0, hazardous = 0
        for seed in 1...100 {
            var game = fixture(apples: 18), rng = SurvivorRNG(state: UInt64(seed))
            game.refreshObstacles(using: &rng)
            if game.obstacles.isEmpty { clear += 1 } else { hazardous += 1 }
        }
        XCTAssertGreaterThan(clear, 20)
        XCTAssertGreaterThan(hazardous, 20)
    }
    func testLevelTwentyNineAndLaterAlwaysAttemptSafeObstacleLayout() {
        for apples in [28, 29, 100] {
            for seed in 1...10 {
                var game = fixture(apples: apples), rng = SurvivorRNG(state: UInt64(seed))
                game.refreshObstacles(using: &rng)
                XCTAssertFalse(game.obstacles.isEmpty)
            }
        }
    }
    func testDifferentLayoutsAndSafePlacement() {
        var signatures: Set<Set<Cell>> = []
        for seed in 1...40 {
            var game = fixture(apples: 28), rng = SurvivorRNG(state: UInt64(seed))
            game.refreshObstacles(using: &rng)
            XCTAssertTrue(game.obstacles.isDisjoint(with: Set(game.body)))
            XCTAssertFalse(game.obstacles.contains(game.food!.cell))
            XCTAssertTrue(connected(game))
            let head = game.body[0]
            for cell in game.obstacles {
                let dx = min(abs(cell.x-head.x),game.boardSize-abs(cell.x-head.x))
                let dy = min(abs(cell.y-head.y),game.boardSize-abs(cell.y-head.y))
                XCTAssertGreaterThan(dx+dy,4)
            }
            for step in 1...7 { XCTAssertFalse(game.obstacles.contains(Cell(x:(head.x+step)%game.boardSize,y:head.y))) }
            signatures.insert(game.obstacles)
        }
        XCTAssertGreaterThan(signatures.count, 30)
    }
    func testClearRollRemovesEveryPreviousObstacle() {
        let old: Set<Cell> = [Cell(x:1,y:1),Cell(x:1,y:2)]
        var game = fixture(apples: 15, obstacles: old), rng = SurvivorRNG(state: 12)
        game.refreshObstacles(using: &rng, roll: 0.99)
        XCTAssertTrue(game.obstacles.isEmpty)
    }
    func testNewLayoutReplacesOldRatherThanAccumulatingIt() {
        let old: Set<Cell> = [Cell(x:14,y:13)]
        var game = fixture(apples: 28, obstacles: old), rng = SurvivorRNG(state: 12)
        game.tick(elapsed: 0.1, using: &rng)
        XCTAssertFalse(game.obstacles.contains(Cell(x:14,y:13)))
        XCTAssertFalse(game.obstacles.isEmpty)
    }
    func testObstacleHitEndsRunWithoutAwardingPoints() {
        var game = fixture(food: Food(cell:Cell(x:1,y:1),kind:.apple), obstacles:[Cell(x:15,y:14)])
        var rng = SurvivorRNG(state: 32)
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .collision)
        XCTAssertEqual(game.phase,.gameOver)
        XCTAssertEqual(game.collisionCause,.obstacle)
        XCTAssertEqual(game.score.digits,"9")
        XCTAssertEqual(game.body,body)
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng),.none)
    }
    func testWrappedObstacleAlsoKills() {
        var game = SnakeEngine(boardSize:28,body:[Cell(x:27,y:14),Cell(x:26,y:14),Cell(x:25,y:14)],
            food:Food(cell:Cell(x:1,y:1),kind:.apple),mode:.survivor,obstacles:[Cell(x:0,y:14)])
        var rng = SurvivorRNG(state: 42)
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.collision)
        XCTAssertEqual(game.collisionCause,.obstacle)
    }
    func testRatDoesNotAdvanceLevelProbabilityOrRerollExistingLayout() {
        let old: Set<Cell> = [Cell(x:1,y:1),Cell(x:1,y:2)]
        var game = fixture(apples:8,food:Food(cell:Cell(x:15,y:14),kind:.rat,secondsRemaining:8),obstacles:old)
        var rng = SurvivorRNG(state: 5)
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.rat)
        XCTAssertEqual(game.score.digits,"40")
        XCTAssertEqual(game.level.digits,"9")
        XCTAssertEqual(game.obstacleProbability,0)
        XCTAssertEqual(game.obstacles,old)
        XCTAssertFalse(game.obstacles.contains(game.food!.cell))
    }
    func testPauseResumeAndMovementDoNotReroll() {
        var game = fixture(apples:28,food:Food(cell:Cell(x:1,y:1),kind:.apple)), rng = SurvivorRNG(state: 58)
        game.refreshObstacles(using:&rng)
        let original = game.obstacles
        game.pause(); XCTAssertEqual(game.tick(elapsed:3,using:&rng),.none)
        XCTAssertEqual(game.obstacles,original)
        game.resume(); XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.moved)
        XCTAssertEqual(game.obstacles,original)
    }
    func testFoodNeverSpawnsOnBlocksOrBody() {
        for seed in 1...40 {
            var game = fixture(apples:28),rng = SurvivorRNG(state:UInt64(seed))
            game.tick(elapsed:0.1,using:&rng)
            XCTAssertNotNil(game.food)
            XCTAssertFalse(game.obstacles.contains(game.food!.cell))
            XCTAssertFalse(game.body.contains(game.food!.cell))
        }
    }
    func testRestartClearsBlocksAndDeathState() {
        var game = fixture(obstacles:[Cell(x:15,y:14)]),rng = SurvivorRNG(state: 5)
        game.tick(elapsed:0.1,using:&rng)
        game.start(mode:.survivor,using:&rng)
        XCTAssertEqual(game.level.digits,"1")
        XCTAssertTrue(game.obstacles.isEmpty)
        XCTAssertNil(game.collisionCause)
        XCTAssertEqual(game.mode,.survivor)
        XCTAssertEqual(game.movesPerSecond,SnakeEngine.initialMovesPerSecond)
    }
    func testDenseBoardFallsBackToClearRatherThanTrappingPlayer() {
        let cells=(0..<4).flatMap{y in (0..<4).map{x in Cell(x:x,y:y)}}
        var game=SnakeEngine(boardSize:4,body:Array(cells.prefix(12)),food:Food(cell:cells[12],kind:.apple),applesEaten:99,mode:.survivor)
        var rng=SurvivorRNG(state:4)
        game.refreshObstacles(using:&rng)
        XCTAssertTrue(game.obstacles.isEmpty)
    }
    func testSpeedRunRatFrequencyAndProgression() {
        var counts: [GameMode:Int] = [.classic:0,.speedRun:0]
        for mode in [GameMode.classic,.speedRun] {
            for seed in 1...500 {
                var game=SnakeEngine(body:[Cell(x:3,y:3),Cell(x:2,y:3)],
                    food:Food(cell:Cell(x:4,y:3),kind:.apple),applesEaten:3,mode:mode)
                var rng=SurvivorRNG(state:UInt64(seed))
                game.tick(elapsed:0.1,using:&rng)
                if game.food?.kind == .rat { counts[mode,default:0] += 1 }
            }
        }
        XCTAssertGreaterThan(counts[.speedRun]!, counts[.classic]! * 3 / 2)
        var game=SnakeEngine(body:[Cell(x:3,y:3),Cell(x:2,y:3)],
            food:Food(cell:Cell(x:4,y:3),kind:.rat,secondsRemaining:8),score:ArcadeScore("7"),applesEaten:3,mode:.speedRun)
        var rng=SurvivorRNG(state:8)
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.rat)
        XCTAssertEqual(game.score.digits,"35")
        XCTAssertEqual(game.level.digits,"4")
        XCTAssertEqual(game.movesPerSecond,SnakeEngine.initialMovesPerSecond * 5,accuracy:0.000001)
    }
}
