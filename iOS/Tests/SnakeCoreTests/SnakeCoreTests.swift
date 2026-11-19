import XCTest
@testable import SnakeCore

private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64 = 42
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class ArcadeScoreTests: XCTestCase {
    func testNormalizationAndInvalidScores() {
        XCTAssertEqual(ArcadeScore("000123").digits, "123")
        XCTAssertEqual(ArcadeScore("000").digits, "0")
        for text in ["", "-1", "NaN", "12.3", "12a", "１２"] {
            XCTAssertEqual(ArcadeScore(text).digits, "0")
        }
    }

    func testCarryAndLevel() {
        var value = ArcadeScore("99999")
        value.addOne()
        XCTAssertEqual(value.digits, "100000")
        XCTAssertEqual(value.nextLevel.digits, "100001")
        XCTAssertEqual(value.digits, "100000")
    }

    func testFiveTimesExactly() {
        var value = ArcadeScore("12")
        value.multiplyByFive()
        XCTAssertEqual(value.digits, "60")
        var zero = ArcadeScore()
        zero.multiplyByFive()
        XCTAssertEqual(zero.digits, "0")
    }

    func testRepeatedMultipliersBeyondMachineInteger() {
        var value = ArcadeScore("1")
        for _ in 0..<100 { value.multiplyByFive() }
        XCTAssertEqual(value.digits,
            "7888609052210118054117285652827862296732064351090230047702789306640625")
        XCTAssertEqual(value.compact, "7.88e69")
        XCTAssertEqual(value.speedValue, 1_000_000)
    }

    func testComparisonAndCompactDisplay() {
        XCTAssertLessThan(ArcadeScore("9"), ArcadeScore("10"))
        XCTAssertLessThan(ArcadeScore("100"), ArcadeScore("101"))
        XCTAssertEqual(ArcadeScore("1234").compact, "1.23K")
        XCTAssertEqual(ArcadeScore("12000").compact, "12.0K")
        XCTAssertEqual(ArcadeScore("5000000").compact, "5.00M")
    }
}

final class SnakeEngineTests: XCTestCase {
    private let safeFood = Food(cell: Cell(x: 5, y: 5), kind: .apple)

    func testNewGameAndReset() {
        var rng = SeededRandom()
        var game = SnakeEngine()
        XCTAssertEqual(game.phase, .ready)
        game.start(using: &rng)
        XCTAssertEqual(game.phase, .running)
        XCTAssertEqual(game.body.count, 3)
        XCTAssertEqual(game.score.digits, "0")
        XCTAssertEqual(game.level.digits, "1")
        XCTAssertEqual(game.movementInterval, 0.195, accuracy: 0.000001)
        XCTAssertFalse(game.body.contains(game.food!.cell))
        XCTAssertEqual(game.food!.kind, .apple)
    }

    func testWrappingAcrossAllFourEdges() {
        let cases: [(Direction, [Cell], Cell)] = [
            (.right, [Cell(x: 19,y: 10), Cell(x: 18,y: 10), Cell(x: 17,y: 10)], Cell(x: 0,y: 10)),
            (.left, [Cell(x: 0,y: 10), Cell(x: 1,y: 10), Cell(x: 2,y: 10)], Cell(x: 19,y: 10)),
            (.up, [Cell(x: 10,y: 0), Cell(x: 10,y: 1), Cell(x: 10,y: 2)], Cell(x: 10,y: 19)),
            (.down, [Cell(x: 10,y: 19), Cell(x: 10,y: 18), Cell(x: 10,y: 17)], Cell(x: 10,y: 0))
        ]
        for (direction, body, expected) in cases {
            var game = SnakeEngine(body: body, direction: direction, food: safeFood)
            var rng = SeededRandom()
            XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .moved)
            XCTAssertEqual(game.body[0], expected)
            XCTAssertEqual(game.phase, .running)
        }
    }

    func testTurnBufferAndReverseProtection() {
        var rng = SeededRandom()
        var game = SnakeEngine()
        game.start(using: &rng)
        XCTAssertFalse(game.turn(.left))
        XCTAssertFalse(game.turn(.right))
        XCTAssertTrue(game.turn(.up))
        XCTAssertFalse(game.turn(.down))
        XCTAssertTrue(game.turn(.left))
        XCTAssertFalse(game.turn(.down)) // Buffer is full.
        game.tick(elapsed: 0.1, using: &rng)
        XCTAssertEqual(game.direction, .up)
        game.tick(elapsed: 0.1, using: &rng)
        XCTAssertEqual(game.direction, .left)
        XCTAssertEqual(game.body[0], Cell(x: 9, y: 9))
    }

    func testAppleGrowsScoresAndSpeedsUp() {
        var game = SnakeEngine(body: [Cell(x: 3,y: 3), Cell(x: 2,y: 3), Cell(x: 1,y: 3)],
                               food: Food(cell: Cell(x: 4,y: 3), kind: .apple),
                               score: ArcadeScore("9"), applesEaten: 9, rules: GameRules(ratChance: 0))
        let oldInterval = game.movementInterval
        var rng = SeededRandom()
        XCTAssertEqual(game.tick(elapsed: oldInterval, using: &rng), .apple)
        XCTAssertEqual(game.score.digits, "10")
        XCTAssertEqual(game.level.digits, "11")
        XCTAssertEqual(game.body.count, 4)
        XCTAssertEqual(game.applesEaten, 10)
        XCTAssertLessThan(game.movementInterval, oldInterval)
        XCTAssertFalse(game.body.contains(game.food!.cell))
    }

    func testRatMultipliesCurrentScoreNotAddsFive() {
        var game = SnakeEngine(body: [Cell(x: 3,y: 3), Cell(x: 2,y: 3), Cell(x: 1,y: 3)],
                               food: Food(cell: Cell(x: 4,y: 3), kind: .rat),
                               score: ArcadeScore("12"), applesEaten: 3)
        var rng = SeededRandom()
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .rat)
        XCTAssertEqual(game.score.digits, "60")
        XCTAssertEqual(game.level.digits, "4")
        XCTAssertEqual(game.movesPerSecond, SnakeEngine.initialMovesPerSecond * 5, accuracy: 0.000001)
        XCTAssertEqual(game.ratsEaten, 1)
        XCTAssertEqual(game.applesEaten, 3)
        XCTAssertEqual(game.body.count, 4)
    }

    func testClassicAndSurvivorRatsPersistUntilEaten() {
        for mode in [GameMode.classic, .survivor] {
            let rat = Food(cell: Cell(x: 8,y: 3), kind: .rat)
            var game = SnakeEngine(body: [Cell(x: 3,y: 3), Cell(x: 2,y: 3), Cell(x: 1,y: 3)],
                                   food: rat, score: ArcadeScore("12"), applesEaten: 3, mode: mode)
            var rng = SeededRandom()
            for _ in 0..<4 {
                XCTAssertEqual(game.tick(elapsed: 100, using: &rng), .moved)
                XCTAssertEqual(game.food, rat)
            }
            game.pause()
            let body = game.body
            XCTAssertFalse(game.turn(.up))
            XCTAssertEqual(game.tick(elapsed: 100, using: &rng), .none)
            XCTAssertEqual(game.body, body)
            XCTAssertEqual(game.food, rat)
            game.resume()
            XCTAssertEqual(game.tick(elapsed: 100, using: &rng), .rat)
            XCTAssertEqual(game.score.digits, "60")
            XCTAssertEqual(game.level.digits, "4")
            XCTAssertEqual(game.body.count, 4)
        }
    }

    func testEachModeHasItsOwnSpeedCapAndFixtureClamp() {
        for mode in GameMode.allCases {
            let cap = mode == .speedRun ? 100.0 : 60.0
            XCTAssertEqual(mode.maximumMovesPerSecond, cap)
            let game = SnakeEngine(body: [Cell(x: 3,y: 3)], food: nil,
                                   mode: mode, movesPerSecond: 1000)
            XCTAssertEqual(game.movesPerSecond, cap)
            XCTAssertEqual(game.movementInterval, 1 / cap, accuracy: 0.000001)
        }
    }

    func testMovingIntoVacatingTailIsAllowed() {
        var game = SnakeEngine(boardSize: 6,
            body: [Cell(x: 1,y: 1), Cell(x: 1,y: 2), Cell(x: 2,y: 2), Cell(x: 2,y: 1)],
            food: Food(cell: Cell(x: 5,y: 5), kind: .apple))
        var rng = SeededRandom()
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .moved)
        XCTAssertEqual(game.body[0], Cell(x: 2,y: 1))
        XCTAssertEqual(Set(game.body).count, 4)
    }

    func testSelfCollisionStopsGame() {
        var game = SnakeEngine(boardSize: 6,
            body: [Cell(x: 1,y: 1), Cell(x: 0,y: 1), Cell(x: 0,y: 2), Cell(x: 1,y: 2),
                   Cell(x: 2,y: 2), Cell(x: 2,y: 1), Cell(x: 3,y: 1)],
            food: Food(cell: Cell(x: 5,y: 5), kind: .apple))
        var rng = SeededRandom()
        let oldBody = game.body
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .collision)
        XCTAssertEqual(game.phase, .gameOver)
        XCTAssertEqual(game.body, oldBody)
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .none)
    }

    func testRatsEligibleAfterThirdApple() {
        var rng = SeededRandom()
        for apples in 0...2 {
            var game = SnakeEngine(body: [Cell(x: 3,y: 3), Cell(x: 2,y: 3), Cell(x: 1,y: 3)],
                food: Food(cell: Cell(x: 4,y: 3), kind: .apple), applesEaten: apples,
                rules: GameRules(ratChance: 1))
            game.tick(elapsed: 0.1, using: &rng)
            XCTAssertEqual(game.food!.kind, apples == 2 ? .rat : .apple)
            XCTAssertFalse(game.body.contains(game.food!.cell))
        }
    }

    func testFirstFoodIsAlwaysAnApple() {
        var game = SnakeEngine(rules: GameRules(ratChance: 1, applesBeforeRats: 0))
        var rng = SeededRandom()
        for _ in 0..<100 {
            game.start(using: &rng)
            XCTAssertEqual(game.food!.kind, .apple)
            XCTAssertFalse(game.body.contains(game.food!.cell))
        }
    }

    func testFullBoardWinsWithoutSpawningInvalidFood() {
        let body = [Cell(x: 0,y: 0), Cell(x: 1,y: 0), Cell(x: 2,y: 0), Cell(x: 3,y: 0),
                    Cell(x: 3,y: 1), Cell(x: 2,y: 1), Cell(x: 1,y: 1), Cell(x: 0,y: 1),
                    Cell(x: 0,y: 2), Cell(x: 1,y: 2), Cell(x: 2,y: 2), Cell(x: 3,y: 2),
                    Cell(x: 3,y: 3), Cell(x: 2,y: 3), Cell(x: 1,y: 3)]
        var game = SnakeEngine(boardSize: 4, body: body, direction: .up,
                               food: Food(cell: Cell(x: 0,y: 3), kind: .apple))
        var rng = SeededRandom()
        XCTAssertEqual(game.tick(elapsed: 0.1, using: &rng), .won)
        XCTAssertEqual(game.body.count, 16)
        XCTAssertEqual(game.phase, .won)
        XCTAssertNil(game.food)
        XCTAssertEqual(game.score.digits, "1")
    }

    func testLargeScoreDoesNotChangeLevelOrSpeed() {
        let game = SnakeEngine(body: [Cell(x: 3,y: 3), Cell(x: 2,y: 3), Cell(x: 1,y: 3)],
            food: safeFood, score: ArcadeScore(String(repeating: "9", count: 250)))
        XCTAssertEqual(game.movementInterval, 0.195)
        XCTAssertTrue(game.movementInterval.isFinite)
        XCTAssertEqual(game.level.digits, "1")
    }

    func testRatMultipliesCurrentSpeedAndCapsItWithoutChangingLevel() {
        for rate in [2.0, 8.0, 12.0, 30.0, 60.0] {
            var game = SnakeEngine(body: [Cell(x: 3,y: 3), Cell(x: 2,y: 3)],
                food: Food(cell: Cell(x: 4,y: 3), kind: .rat),
                applesEaten: 8, movesPerSecond: rate)
            var rng = SeededRandom()
            XCTAssertEqual(game.tick(elapsed: 0.01, using: &rng), .rat)
            XCTAssertEqual(game.movesPerSecond, min(60, rate * 5), accuracy: 0.000001)
            XCTAssertEqual(game.level.digits, "9")
            XCTAssertEqual(game.score.digits, "0")
        }
    }
}
