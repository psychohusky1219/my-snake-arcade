import XCTest
@testable import SnakeCore

private struct SpeedRunRNG: RandomNumberGenerator {
    var state: UInt64 = 41
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class SpeedRunTests: XCTestCase {
    private let body = [Cell(x:3,y:3),Cell(x:2,y:3),Cell(x:1,y:3)]
    private let collisionBody = [Cell(x:1,y:1),Cell(x:0,y:1),Cell(x:0,y:2),Cell(x:1,y:2),
                                 Cell(x:2,y:2),Cell(x:2,y:1),Cell(x:3,y:1)]
    private func fixture(items:[Food] = [Food(cell:Cell(x:0,y:0),kind:.apple)],
                         shield:Double = 0, phase:GamePhase = .running,
                         recovery:Bool = false) -> SnakeEngine {
        SnakeEngine(body:body,food:nil,score:ArcadeScore("7"),applesEaten:3,phase:phase,
                    mode:.speedRun,movesPerSecond:6,speedRunFoods:items,
                    shieldSecondsRemaining:shield,shieldRecovery:recovery)
    }
    private func collisionFixture(shield:Double = 10) -> SnakeEngine {
        SnakeEngine(boardSize:6,body:collisionBody,food:nil,score:ArcadeScore("7"),
            mode:.speedRun,speedRunFoods:[Food(cell:Cell(x:5,y:5),kind:.rat)],shieldSecondsRemaining:shield)
    }
    func testShieldConsumesOneWallHitWithoutWrapping() {
        let edge = Cell(x: 19,y: 3)
        var game = SnakeEngine(body: [edge], food: nil, mode: .speedRun,
                               shieldSecondsRemaining: 10, wallWrap: false)
        var rng = SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed: 0.01, using: &rng), .shielded)
        XCTAssertEqual(game.body.first, edge)
        XCTAssertEqual(game.shieldSecondsRemaining, 0)
        XCTAssertTrue(game.turn(.up))
        game.resume()
        XCTAssertEqual(game.tick(elapsed: 0.01, using: &rng), .moved)
        XCTAssertEqual(game.body.first, Cell(x: 19,y: 2))
    }

    func testSpeedRunApplesAndRatsReach240WithoutExceedingIt() {
        for kind in [FoodKind.apple, .rat] {
            for rate in [20.0, 60.0, 239.9, 240.0] {
                var game = SnakeEngine(body: body, food: nil, score: ArcadeScore("7"),
                    applesEaten: 3, mode: .speedRun, movesPerSecond: rate,
                    speedRunFoods: [Food(cell: Cell(x: 4,y: 3), kind: kind)])
                var rng = SpeedRunRNG()
                XCTAssertEqual(game.tick(elapsed: 100, using: &rng), kind == .rat ? .rat : .apple)
                let expected = kind == .rat ? min(240, rate * 5) : min(240, rate + SnakeEngine.appleSpeedIncrement)
                XCTAssertEqual(game.movesPerSecond, expected, accuracy: 0.000001)
                XCTAssertEqual(game.level.digits, kind == .rat ? "4" : "5")
            }
        }
    }

    func testStartsWithTwelveUniquePersistentPickupsAndImmediateRats() {
        for seed in 1...30 {
            var game=SnakeEngine(),rng=SpeedRunRNG(state:UInt64(seed))
            game.start(mode:.speedRun,using:&rng)
            XCTAssertNil(game.food)
            XCTAssertEqual(game.speedRunFoods.count,12)
            XCTAssertEqual(game.speedRunFoods.filter{$0.kind == .apple}.count,6)
            XCTAssertEqual(game.speedRunFoods.filter{$0.kind == .rat}.count,5)
            XCTAssertEqual(game.speedRunFoods.filter{$0.kind == .blueBird}.count,1)
            XCTAssertEqual(Set(game.speedRunFoods.map(\.cell)).count,12)
            XCTAssertTrue(game.speedRunFoods.allSatisfy{!game.body.contains($0.cell) && !game.obstacles.contains($0.cell)})
            XCTAssertEqual(game.applesEaten,0)
        }
    }
    func testUntouchedPickupsDoNotExpireOrMoveAfterEightSeconds() {
        let items=[Food(cell:Cell(x:1,y:1),kind:.rat),Food(cell:Cell(x:2,y:1),kind:.apple),Food(cell:Cell(x:3,y:1),kind:.blueBird)]
        var game=fixture(items:items),rng=SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed:12,using:&rng),.moved)
        XCTAssertEqual(game.speedRunFoods,items)
    }
    func testEatingReplacesOnlyConsumedItemAndPreservesUntouchedItems() {
        for kind in [FoodKind.apple,.rat,.blueBird] {
            let untouched=[Food(cell:Cell(x:1,y:1),kind:.rat),Food(cell:Cell(x:2,y:1),kind:.blueBird)]
            var game=fixture(items:untouched+[Food(cell:Cell(x:4,y:3),kind:kind)]),rng=SpeedRunRNG()
            let event=game.tick(elapsed:0.1,using:&rng)
            XCTAssertEqual(event,kind == .apple ? .apple : (kind == .rat ? .rat : .blueBird))
            XCTAssertEqual(game.speedRunFoods.count,3)
            for item in untouched { XCTAssertTrue(game.speedRunFoods.contains(item)) }
            XCTAssertFalse(game.speedRunFoods.contains{$0.cell == Cell(x:4,y:3)})
            XCTAssertEqual(Set(game.speedRunFoods.map(\.cell)).count,3)
            XCTAssertTrue(game.speedRunFoods.allSatisfy{!game.body.contains($0.cell)})
        }
    }
    func testReplacementDistributionIncludesApplesRatsAndBirds() {
        var apples=0,rats=0,birds=0
        for seed in 1...1000 {
            var game=fixture(items:[Food(cell:Cell(x:4,y:3),kind:.apple)]),rng=SpeedRunRNG(state:UInt64(seed))
            game.tick(elapsed:0.1,using:&rng)
            switch game.speedRunFoods[0].kind { case .apple: apples += 1; case .rat: rats += 1; case .blueBird: birds += 1 }
        }
        XCTAssertTrue((350...550).contains(apples))
        XCTAssertTrue((350...550).contains(rats))
        XCTAssertTrue((50...150).contains(birds))
    }
    func testBlueBirdGrantsFullShieldWithoutProgressionOrGrowth() {
        var game=fixture(items:[Food(cell:Cell(x:4,y:3),kind:.blueBird)]),rng=SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed:4,using:&rng),.blueBird)
        XCTAssertEqual(game.shieldSecondsRemaining,10)
        XCTAssertEqual(game.body.count,3)
        XCTAssertEqual(game.score.digits,"7")
        XCTAssertEqual(game.level.digits,"4")
        XCTAssertEqual(game.applesEaten,3)
        XCTAssertEqual(game.ratsEaten,0)
        XCTAssertEqual(game.movesPerSecond,6)
    }
    func testAnotherBirdRefreshesRatherThanStacksShield() {
        var game=fixture(items:[Food(cell:Cell(x:4,y:3),kind:.blueBird)],shield:9),rng=SpeedRunRNG()
        game.tick(elapsed:2,using:&rng)
        XCTAssertEqual(game.shieldSecondsRemaining,10)
    }
    func testShieldCountsOnlyFiniteNonnegativeActiveTimeAndPauseFreezesIt() {
        var game=fixture(shield:10),rng=SpeedRunRNG()
        for elapsed in [-5.0,Double.nan,Double.infinity] {
            game.tick(elapsed:elapsed,using:&rng)
            XCTAssertEqual(game.shieldSecondsRemaining,10)
        }
        game.tick(elapsed:2.5,using:&rng)
        XCTAssertEqual(game.shieldSecondsRemaining,7.5)
        game.pause()
        XCTAssertEqual(game.tick(elapsed:100,using:&rng),.none)
        XCTAssertEqual(game.shieldSecondsRemaining,7.5)
        XCTAssertFalse(game.turn(.up))
        game.resume()
        game.tick(elapsed:7.5,using:&rng)
        XCTAssertEqual(game.shieldSecondsRemaining,0)
        XCTAssertEqual(game.phase,.running)
    }
    func testExactShieldExpiryDoesNotProtectCollision() {
        var game=collisionFixture(shield:1),rng=SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed:1,using:&rng),.collision)
        XCTAssertEqual(game.phase,.gameOver)
        XCTAssertEqual(game.shieldSecondsRemaining,0)
        XCTAssertFalse(game.shieldRecovery)
    }
    func testShieldCancelsCollisionPreservingBodyFoodAndScoreThenPauses() {
        var game=collisionFixture(),rng=SpeedRunRNG()
        let originalBody=game.body,items=game.speedRunFoods
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.shielded)
        XCTAssertEqual(game.phase,.paused)
        XCTAssertTrue(game.shieldRecovery)
        XCTAssertEqual(game.shieldSecondsRemaining,0)
        XCTAssertEqual(game.body,originalBody)
        XCTAssertEqual(game.speedRunFoods,items)
        XCTAssertEqual(game.score.digits,"7")
        XCTAssertNil(game.collisionCause)
        XCTAssertEqual(game.tick(elapsed:20,using:&rng),.none)
        XCTAssertEqual(game.body,originalBody)
    }
    func testShieldAlsoProtectsAgainstFixtureObstacle() {
        var game=SnakeEngine(body:body,food:nil,mode:.speedRun,obstacles:[Cell(x:4,y:3)],
            speedRunFoods:[Food(cell:Cell(x:1,y:1),kind:.apple)],shieldSecondsRemaining:10)
        var rng=SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.shielded)
        XCTAssertEqual(game.body,body)
        XCTAssertEqual(game.obstacles,[Cell(x:4,y:3)])
    }
    func testRecoveryAllowsSafeSteeringAndResumeClearsRecoveryFlag() {
        var game=collisionFixture(),rng=SpeedRunRNG()
        game.tick(elapsed:0.1,using:&rng)
        XCTAssertFalse(game.turn(.left)) // Normal reverse protection remains.
        XCTAssertTrue(game.turn(.up))
        game.resume()
        XCTAssertFalse(game.shieldRecovery)
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.moved)
        XCTAssertEqual(game.body[0],Cell(x:1,y:0))
        XCTAssertEqual(game.body.count,collisionBody.count)
        XCTAssertEqual(game.phase,.running)
    }
    func testResumeWithoutSteeringMakesSecondCollisionLethal() {
        var game=collisionFixture(),rng=SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.shielded)
        game.resume()
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.collision)
        XCTAssertEqual(game.phase,.gameOver)
        XCTAssertEqual(game.collisionCause,.body)
    }
    func testShieldHitClearsQueuedTurnsBeforeRecovery() {
        // First queued turn hits the body; the second must be discarded.
        var game=SnakeEngine(boardSize:6,
            body:[Cell(x:1,y:1),Cell(x:0,y:1),Cell(x:0,y:0),Cell(x:1,y:0),Cell(x:2,y:0)],
            food:nil,mode:.speedRun,shieldSecondsRemaining:10)
        var rng=SpeedRunRNG()
        XCTAssertTrue(game.turn(.up))
        XCTAssertTrue(game.turn(.left))
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.shielded)
        XCTAssertTrue(game.turn(.right))
        game.resume()
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.moved)
        XCTAssertEqual(game.direction,.right)
        XCTAssertEqual(game.body[0],Cell(x:2,y:1))
    }
    func testBirdOnVacatingTailDoesNotCountAsGrowthOrSelfCollision() {
        let bent=[Cell(x:1,y:1),Cell(x:1,y:2),Cell(x:2,y:2),Cell(x:2,y:1)]
        var game=SnakeEngine(boardSize:6,body:bent,food:nil,mode:.speedRun,
            speedRunFoods:[Food(cell:Cell(x:2,y:1),kind:.blueBird)])
        var rng=SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.blueBird)
        XCTAssertEqual(game.body.count,4)
        XCTAssertEqual(Set(game.body).count,4)
        XCTAssertEqual(game.body[0],Cell(x:2,y:1))
        XCTAssertEqual(game.shieldSecondsRemaining,10)
    }
    func testNearFullBoardWinsWhenLastAppleFillsIt() {
        let path=[Cell(x:0,y:0),Cell(x:1,y:0),Cell(x:2,y:0),Cell(x:3,y:0),
                  Cell(x:3,y:1),Cell(x:2,y:1),Cell(x:1,y:1),Cell(x:0,y:1),
                  Cell(x:0,y:2),Cell(x:1,y:2),Cell(x:2,y:2),Cell(x:3,y:2),
                  Cell(x:3,y:3),Cell(x:2,y:3),Cell(x:1,y:3)]
        var game=SnakeEngine(boardSize:4,body:path,direction:.up,food:nil,mode:.speedRun,
            speedRunFoods:[Food(cell:Cell(x:0,y:3),kind:.apple)])
        var rng=SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.won)
        XCTAssertEqual(game.body.count,16)
        XCTAssertTrue(game.speedRunFoods.isEmpty)
        XCTAssertEqual(game.score.digits,"1")
    }
    func testCrowdedBoardReplacementUsesOnlyAvailableCells() {
        let blocked=Set((0..<4).flatMap{y in (0..<4).map{x in Cell(x:x,y:y)}})
            .subtracting([Cell(x:1,y:1),Cell(x:0,y:1),Cell(x:2,y:1),Cell(x:3,y:3)])
        var game=SnakeEngine(boardSize:4,body:[Cell(x:1,y:1),Cell(x:0,y:1)],food:nil,
            mode:.speedRun,obstacles:blocked,speedRunFoods:[Food(cell:Cell(x:2,y:1),kind:.apple),Food(cell:Cell(x:3,y:3),kind:.rat)])
        var rng=SpeedRunRNG()
        XCTAssertEqual(game.tick(elapsed:0.1,using:&rng),.apple)
        XCTAssertEqual(game.speedRunFoods,[Food(cell:Cell(x:3,y:3),kind:.rat)])
        XCTAssertEqual(game.body.count,3)
        XCTAssertEqual(game.phase,.running)
    }
    func testRestartAndModeSwitchClearShieldRecoveryAndPool() {
        var game=collisionFixture(),rng=SpeedRunRNG()
        game.tick(elapsed:0.1,using:&rng)
        game.start(mode:.speedRun,using:&rng)
        XCTAssertEqual(game.shieldSecondsRemaining,0)
        XCTAssertFalse(game.shieldRecovery)
        XCTAssertEqual(game.speedRunFoods.count,12)
        for mode in [GameMode.classic,.survivor,.endless] {
            game.start(mode:mode,using:&rng)
            XCTAssertTrue(game.speedRunFoods.isEmpty)
            XCTAssertEqual(game.shieldSecondsRemaining,0)
            XCTAssertFalse(game.shieldRecovery)
        }
    }
    func testOtherModesCannotCarryShieldEvenFromFixture() {
        for mode in [GameMode.classic,.survivor,.endless] {
            let game=SnakeEngine(body:body,food:nil,phase:.paused,mode:mode,
                speedRunFoods:[Food(cell:Cell(x:4,y:3),kind:.blueBird)],shieldSecondsRemaining:10,shieldRecovery:true)
            XCTAssertEqual(game.shieldSecondsRemaining,0)
            XCTAssertFalse(game.shieldRecovery)
            XCTAssertTrue(game.speedRunFoods.isEmpty)
        }
    }
}
