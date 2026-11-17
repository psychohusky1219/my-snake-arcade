import XCTest
@testable import SnakeCore

private struct EndlessRNG: RandomNumberGenerator {
    var state: UInt64 = 33
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class EndlessTests: XCTestCase {
    private func fixture(length: Int = 5, x: Int = 10, foods: [Food] = [],
                         obstacles: Set<Cell> = [], rows: Int = 0,
                         speed: Double = 5, steering: Int = 0) -> SnakeEngine {
        SnakeEngine(body: (0..<length).map { Cell(x:x,y:13+$0) }, direction: .up,
            food:nil, mode:.endless, obstacles:obstacles, movesPerSecond:speed,
            endlessFoods:foods, scrollRows:rows, endlessSteering:steering)
    }
    func testStartHasFiveSegmentsAndFoodAhead() {
        var game=SnakeEngine(),rng=EndlessRNG()
        game.start(mode:.endless,using:&rng)
        XCTAssertEqual(game.body.count,5)
        XCTAssertEqual(game.body[0],Cell(x:10,y:13))
        XCTAssertEqual(game.direction,.up)
        XCTAssertEqual(game.movesPerSecond,5)
        XCTAssertEqual(game.endlessFoods,[Food(cell:Cell(x:10,y:9),kind:.apple)])
        XCTAssertNil(game.food)
        XCTAssertTrue(game.obstacles.isEmpty)
    }
    func testWorldMovesDownWhileHeadStaysAnchored() {
        var game=fixture(foods:[Food(cell:Cell(x:2,y:1),kind:.apple)],obstacles:[Cell(x:5,y:2)])
        var rng=EndlessRNG()
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.moved)
        XCTAssertEqual(game.body[0],Cell(x:10,y:13))
        XCTAssertEqual(game.body[1],Cell(x:10,y:14))
        XCTAssertEqual(game.body.count,5)
        XCTAssertEqual(game.endlessFoods[0].cell,Cell(x:2,y:2))
        XCTAssertEqual(game.obstacles,[Cell(x:5,y:3)])
        XCTAssertEqual(game.scrollRows,1)
    }
    func testLatestSteeringPersistsAndBothVerticalControlsStraighten() {
        var game=fixture(),rng=EndlessRNG()
        XCTAssertTrue(game.turn(.left))
        XCTAssertTrue(game.turn(.right))
        game.tick(elapsed:0.2,using:&rng)
        XCTAssertEqual(game.body[0],Cell(x:11,y:13))
        game.tick(elapsed:0.2,using:&rng)
        XCTAssertEqual(game.body[0],Cell(x:12,y:13))
        for direction in [Direction.up,.down] {
            game.turn(.left)
            game.turn(direction)
            game.tick(elapsed:0.2,using:&rng)
            XCTAssertEqual(game.body[0],Cell(x:12,y:13))
        }
        XCTAssertEqual(game.direction,.up)
    }
    func testSideEdgesClampWithoutWrappingOrDamage() {
        for (x,direction) in [(0,Direction.left),(19,Direction.right)] {
            var game=fixture(x:x),rng=EndlessRNG()
            game.turn(direction)
            game.tick(elapsed:0.2,using:&rng)
            XCTAssertEqual(game.body[0].x,x)
            XCTAssertEqual(game.body.count,5)
            XCTAssertEqual(game.phase,.running)
        }
    }
    func testBothFoodsGiveExactlyOnePointAndSegmentWithDifferentAcceleration() {
        for kind in [FoodKind.apple,.rat] {
            var game=fixture(foods:[Food(cell:Cell(x:10,y:12),kind:kind)]),rng=EndlessRNG()
            XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),kind == .apple ? .apple : .rat)
            XCTAssertEqual(game.body.count,6)
            XCTAssertEqual(game.score.digits,"1")
            XCTAssertEqual(game.movesPerSecond,kind == .apple ? 5.12 : 5.36,accuracy:0.000001)
            XCTAssertTrue(game.endlessFoods.isEmpty)
            XCTAssertEqual(game.applesEaten,kind == .apple ? 1 : 0)
            XCTAssertEqual(game.ratsEaten,kind == .rat ? 1 : 0)
        }
    }
    func testScrollingIntoHeadCausesExactlyOneDamageAndConsumesWholeGroup() {
        let block:Set<Cell>=[Cell(x:9,y:12),Cell(x:10,y:12),Cell(x:11,y:12)]
        var game=fixture(obstacles:block),rng=EndlessRNG()
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.damaged)
        XCTAssertEqual(game.body.count,4)
        XCTAssertTrue(game.obstacles.isEmpty)
        XCTAssertEqual(game.phase,.running)
        XCTAssertNil(game.collisionCause)
        game.turn(.right)
        game.tick(elapsed:0.2,using:&rng)
        XCTAssertEqual(game.body.count,4)
    }
    func testLateralHeadMovementAndScrollCanCauseContact() {
        var game=fixture(obstacles:[Cell(x:11,y:12)],steering:1),rng=EndlessRNG()
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.damaged)
        XCTAssertEqual(game.body[0],Cell(x:11,y:13))
        XCTAssertEqual(game.body.count,4)
    }
    func testDistinctLaterGroupCanDamageAgain() {
        var game=fixture(obstacles:[Cell(x:10,y:12),Cell(x:10,y:11)]),rng=EndlessRNG()
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.damaged)
        XCTAssertEqual(game.body.count,4)
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.damaged)
        XCTAssertEqual(game.body.count,3)
    }
    func testTailContactsNeverDamageAndOffscreenTailStaysLogicalHealth() {
        var game=fixture(length:30,obstacles:[Cell(x:10,y:13)]),rng=EndlessRNG()
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.moved)
        XCTAssertEqual(game.body.count,30)
        XCTAssertEqual(game.body.last?.y,42)
        XCTAssertEqual(game.phase,.running)
    }
    func testNoSelfCollisionWhenOldBodyCrossesNewHeadPosition() {
        var game=SnakeEngine(body:[Cell(x:10,y:13),Cell(x:11,y:12),Cell(x:12,y:12)],direction:.up,
            food:nil,mode:.endless,movesPerSecond:5,endlessSteering:1)
        var rng=EndlessRNG()
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.moved)
        XCTAssertEqual(game.body.count,3)
        XCTAssertEqual(game.phase,.running)
    }
    func testLastSegmentDamageEndsRunWithoutFurtherProcessing() {
        var game=fixture(length:1,obstacles:[Cell(x:10,y:12)]),rng=EndlessRNG()
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.collision)
        XCTAssertTrue(game.body.isEmpty)
        XCTAssertEqual(game.phase,.gameOver)
        XCTAssertEqual(game.collisionCause,.obstacle)
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.none)
        XCTAssertFalse(game.turn(.left))
    }
    func testSimultaneousFoodAndDamageGrowsBeforeDamage() {
        var game=fixture(length:1,foods:[Food(cell:Cell(x:10,y:12),kind:.rat)],obstacles:[Cell(x:10,y:12)]),rng=EndlessRNG()
        XCTAssertEqual(game.tick(elapsed:0.2,using:&rng),.damaged)
        XCTAssertEqual(game.body.count,1)
        XCTAssertEqual(game.score.digits,"1")
        XCTAssertEqual(game.movesPerSecond,5.36,accuracy:0.000001)
        XCTAssertEqual(game.phase,.running)
    }
    func testPauseFreezesWorldSpeedAndSteering() {
        var game=fixture(foods:[Food(cell:Cell(x:3,y:2),kind:.rat)],obstacles:[Cell(x:9,y:12)]),rng=EndlessRNG()
        let body=game.body,foods=game.endlessFoods,obstacles=game.obstacles
        game.pause()
        XCTAssertFalse(game.turn(.left))
        XCTAssertEqual(game.tick(elapsed:100,using:&rng),.none)
        XCTAssertEqual(game.body,body)
        XCTAssertEqual(game.endlessFoods,foods)
        XCTAssertEqual(game.obstacles,obstacles)
        XCTAssertEqual(game.scrollRows,0)
        XCTAssertEqual(game.movesPerSecond,5)
        game.resume()
        game.tick(elapsed:0.2,using:&rng)
        XCTAssertEqual(game.scrollRows,1)
    }
    func testFoodAndObstacleSpawnCadenceAndNoOverlapOnSameTick() {
        for seed in 1...60 {
            for rows in [3,8,9,14,19] {
                var game=fixture(rows:rows),rng=EndlessRNG(state:UInt64(seed))
                game.tick(elapsed:0.2,using:&rng)
                let tick=rows+1
                XCTAssertEqual(game.endlessFoods.count,tick.isMultiple(of:4) ? 1 : 0)
                if tick >= 10 && tick.isMultiple(of:5) {
                    XCTAssertTrue((1...3).contains(game.obstacles.count))
                    XCTAssertTrue(game.obstacles.allSatisfy { $0.y == 0 })
                    XCTAssertLessThan(game.obstacles.count,game.boardSize)
                } else { XCTAssertTrue(game.obstacles.isEmpty) }
                XCTAssertTrue(game.obstacles.isDisjoint(with:Set(game.endlessFoods.map(\.cell))))
            }
        }
    }
    func testOffscreenWorldObjectsExpire() {
        var game=fixture(foods:[Food(cell:Cell(x:2,y:19),kind:.apple)],obstacles:[Cell(x:2,y:19)]),rng=EndlessRNG()
        game.tick(elapsed:0.2,using:&rng)
        XCTAssertTrue(game.endlessFoods.isEmpty)
        XCTAssertTrue(game.obstacles.isEmpty)
        XCTAssertEqual(game.body.count,5)
    }
    func testEndlessRatSpawnsWithoutAppleGateAndHasNoTimer() {
        var game=SnakeEngine(body:[Cell(x:10,y:13)],direction:.up,food:nil,
            rules:GameRules(ratChance:1),mode:.endless,scrollRows:3)
        var rng=EndlessRNG()
        game.tick(elapsed:0.2,using:&rng)
        XCTAssertEqual(game.applesEaten,0)
        XCTAssertEqual(game.endlessFoods.first?.kind,.rat)
        XCTAssertNil(game.endlessFoods.first?.secondsRemaining)
    }
    func testEndlessSpeedCap() {
        for kind in [FoodKind.apple,.rat] {
            var game=fixture(foods:[Food(cell:Cell(x:10,y:12),kind:kind)],speed:59.99),rng=EndlessRNG()
            game.tick(elapsed:0.03,using:&rng)
            XCTAssertEqual(game.movesPerSecond,60)
        }
    }
    func testRestartAndModeSwitchClearAllEndlessState() {
        var game=fixture(length:1,obstacles:[Cell(x:10,y:12)],rows:19,speed:20,steering:1),rng=EndlessRNG()
        game.tick(elapsed:0.05,using:&rng)
        game.start(mode:.endless,using:&rng)
        XCTAssertEqual(game.body.count,5)
        XCTAssertEqual(game.scrollRows,0)
        XCTAssertEqual(game.movesPerSecond,5)
        XCTAssertTrue(game.obstacles.isEmpty)
        XCTAssertNil(game.collisionCause)
        game.tick(elapsed:0.2,using:&rng)
        XCTAssertEqual(game.body[0].x,10)
        game.start(mode:.speedRun,using:&rng)
        XCTAssertEqual(game.boardSize,35)
        XCTAssertEqual(game.body.count,3)
        XCTAssertTrue(game.endlessFoods.isEmpty)
        XCTAssertEqual(game.scrollRows,0)
        XCTAssertEqual(game.score.digits,"0")
        XCTAssertEqual(game.level.digits,"1")
    }
}
