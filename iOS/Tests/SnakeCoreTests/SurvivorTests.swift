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
    private let body = [Cell(x:10,y:10), Cell(x:9,y:10), Cell(x:8,y:10)]
    private func fixture(score: String = "9", chance: Double = 1, mode: GameMode = .survivor,
                         food: Food? = Food(cell: Cell(x:11,y:10), kind: .apple),
                         obstacles: Set<Cell> = []) -> SnakeEngine {
        SnakeEngine(body: body, food: food, score: ArcadeScore(score), applesEaten: 3,
                    rules: GameRules(ratChance: 0, obstacleChance: chance), mode: mode, obstacles: obstacles)
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
    func testExactlyThreeModesAndSpeedRunIsDisabled() {
        XCTAssertEqual(GameMode.allCases.count, 3)
        XCTAssertEqual(GameMode.survivor.title, "Survivor")
        XCTAssertTrue(GameMode.classic.isPlayable)
        XCTAssertTrue(GameMode.survivor.isPlayable)
        XCTAssertFalse(GameMode.speedRun.isPlayable)
        var game = SnakeEngine(), rng = SurvivorRNG(state: 1)
        game.start(mode: .speedRun, using: &rng)
        XCTAssertEqual(game.phase, .ready)
        XCTAssertEqual(game.tick(elapsed: 1, using: &rng), .none)
    }
    func testLevelsOneThroughNineNeverHaveObstacles() {
        for score in 0...8 {
            var game = fixture(score: String(score)), rng = SurvivorRNG(state: UInt64(score + 1))
            game.refreshObstacles(using: &rng)
            XCTAssertTrue(game.obstacles.isEmpty)
        }
    }
    func testObstaclesCanStartAtLevelTen() {
        var game = fixture(), rng = SurvivorRNG(state: 23)
        game.refreshObstacles(using: &rng)
        XCTAssertEqual(game.level.digits, "10")
        XCTAssertFalse(game.obstacles.isEmpty)
    }
    func testAppleReachingLevelNineIsStillClear() {
        var game = fixture(score: "7"), rng = SurvivorRNG(state: 23)
        game.tick(elapsed: 0.1, using: &rng)
        XCTAssertEqual(game.level.digits, "9")
        XCTAssertTrue(game.obstacles.isEmpty)
    }
    func testAppleReachingTenRollsNewLayout() {
        var game = fixture(score: "8"), rng = SurvivorRNG(state: 23)
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .apple)
        XCTAssertEqual(game.level.digits, "10")
        XCTAssertFalse(game.obstacles.isEmpty)
        XCTAssertFalse(game.obstacles.contains(game.food!.cell))
    }
    func testClassicNeverGetsObstacles() {
        for score in ["0", "9", "1000", String(repeating: "9", count: 90)] {
            var game = fixture(score: score, mode: .classic), rng = SurvivorRNG(state: 99)
            game.refreshObstacles(using: &rng)
            XCTAssertTrue(game.obstacles.isEmpty)
        }
    }
    func testRandomRollProducesClearAndObstacleLevels() {
        var clear = 0, hazardous = 0
        for seed in 1...100 {
            var game = fixture(chance: 0.5), rng = SurvivorRNG(state: UInt64(seed))
            game.refreshObstacles(using: &rng)
            if game.obstacles.isEmpty { clear += 1 } else { hazardous += 1 }
        }
        XCTAssertGreaterThan(clear, 20)
        XCTAssertGreaterThan(hazardous, 20)
    }
    func testDifferentLayoutsAndSafePlacement() {
        var signatures: Set<Set<Cell>> = []
        for seed in 1...80 {
            var game = fixture(), rng = SurvivorRNG(state: UInt64(seed))
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
            for step in 1...7 { XCTAssertFalse(game.obstacles.contains(Cell(x:(head.x+step)%20,y:head.y))) }
            signatures.insert(game.obstacles)
        }
        XCTAssertGreaterThan(signatures.count, 50)
    }
    func testClearLevelRemovesAllPreviousObstacles() {
        let old: Set<Cell> = [Cell(x:1,y:1),Cell(x:1,y:2)]
        var game = fixture(score: "15", chance: 0, obstacles: old), rng = SurvivorRNG(state: 12)
        game.tick(elapsed: 0.1, using: &rng)
        XCTAssertEqual(game.level.digits,"17")
        XCTAssertTrue(game.obstacles.isEmpty)
    }
    func testObstacleHitEndsRunWithoutAwardingPoints() {
        var game = fixture(food: Food(cell:Cell(x:1,y:1),kind:.apple), obstacles:[Cell(x:11,y:10)])
        var rng = SurvivorRNG(state: 32)
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .collision)
        XCTAssertEqual(game.phase,.gameOver)
        XCTAssertEqual(game.collisionCause,.obstacle)
        XCTAssertEqual(game.score.digits,"9")
        XCTAssertEqual(game.body,body)
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng),.none)
    }
    func testWrappedObstacleAlsoKills() {
        var game = SnakeEngine(body:[Cell(x:19,y:10),Cell(x:18,y:10),Cell(x:17,y:10)],
            food:Food(cell:Cell(x:1,y:1),kind:.apple),score:ArcadeScore("10"),mode:.survivor,obstacles:[Cell(x:0,y:10)])
        var rng = SurvivorRNG(state: 42)
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.collision)
        XCTAssertEqual(game.collisionCause,.obstacle)
    }
    func testRatJumpAcrossTenRollsForDestinationLevel() {
        var game = fixture(score:"3",food:Food(cell:Cell(x:11,y:10),kind:.rat,secondsRemaining:8))
        var rng = SurvivorRNG(state: 5)
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.rat)
        XCTAssertEqual(game.score.digits,"15")
        XCTAssertEqual(game.level.digits,"16")
        XCTAssertFalse(game.obstacles.isEmpty)
        XCTAssertFalse(game.obstacles.contains(game.food!.cell))
    }
    func testPauseResumeAndMovementDoNotReroll() {
        var game = fixture(food:Food(cell:Cell(x:1,y:1),kind:.apple)), rng = SurvivorRNG(state: 58)
        game.refreshObstacles(using:&rng)
        let original = game.obstacles
        game.pause(); XCTAssertEqual(game.tick(elapsed:3,using:&rng),.none)
        XCTAssertEqual(game.obstacles,original)
        game.resume(); XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.moved)
        XCTAssertEqual(game.obstacles,original)
    }
    func testFoodNeverSpawnsOnBlocksOrBody() {
        for seed in 1...120 {
            var game = fixture(),rng = SurvivorRNG(state:UInt64(seed))
            game.tick(elapsed:0.1,using:&rng)
            XCTAssertNotNil(game.food)
            XCTAssertFalse(game.obstacles.contains(game.food!.cell))
            XCTAssertFalse(game.body.contains(game.food!.cell))
        }
    }
    func testRestartClearsBlocksAndDeathState() {
        var game = fixture(obstacles:[Cell(x:11,y:10)]),rng = SurvivorRNG(state: 5)
        game.tick(elapsed:0.1,using:&rng)
        game.start(mode:.survivor,using:&rng)
        XCTAssertEqual(game.level.digits,"1")
        XCTAssertTrue(game.obstacles.isEmpty)
        XCTAssertNil(game.collisionCause)
        XCTAssertEqual(game.mode,.survivor)
    }
    func testDenseBoardFallsBackToClearRatherThanTrappingPlayer() {
        let cells=(0..<4).flatMap{y in (0..<4).map{x in Cell(x:x,y:y)}}
        var game=SnakeEngine(boardSize:4,body:Array(cells.prefix(12)),food:Food(cell:cells[12],kind:.apple),score:ArcadeScore("99"),rules:GameRules(obstacleChance:1),mode:.survivor)
        var rng=SurvivorRNG(state:4)
        game.refreshObstacles(using:&rng)
        XCTAssertTrue(game.obstacles.isEmpty)
    }
}
