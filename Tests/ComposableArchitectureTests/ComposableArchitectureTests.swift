import ReactiveSwift
import ComposableArchitecture
import XCTest

final class ComposableArchitectureTests: XCTestCase {
  func testScheduling() {
    enum CounterAction: Equatable {
      case incrAndSquareLater
      case incrNow
      case squareNow
    }

    let counterReducer = Reducer<Int, CounterAction, DateScheduler> {
      state, action, scheduler in
      switch action {
      case .incrAndSquareLater:
        return .merge(
          Effect(value: .incrNow)
            .delay(2, on: scheduler),
          Effect(value: .squareNow)
            .delay(1, on: scheduler),
          Effect(value: .squareNow)
            .delay(2, on: scheduler)
        )
      case .incrNow:
        state += 1
        return .none
      case .squareNow:
        state *= state
        return .none
      }
    }

    let scheduler = TestScheduler()

    let store = TestStore(
      initialState: 2,
      reducer: counterReducer,
      environment: scheduler
    )

    store.assert(
      .send(.incrAndSquareLater),
      .do { scheduler.advance(by: .seconds(1)) },
      .receive(.squareNow) { $0 = 4 },
      .do { scheduler.advance(by: .seconds(1)) },
      .receive(.incrNow) { $0 = 5 },
      .receive(.squareNow) { $0 = 25 }
    )

    store.assert(
      .send(.incrAndSquareLater),
      .do { scheduler.advance(by: .seconds(2)) },
      .receive(.squareNow) { $0 = 625 },
      .receive(.incrNow) { $0 = 626 },
      .receive(.squareNow) { $0 = 391876 }
    )
  }

  func testSimultaneousWorkOrdering() {
    let testScheduler = TestScheduler()

    var values: [Int] = []
    testScheduler.schedule(after: .seconds(0), interval: .seconds(1)) { values.append(1) }
    testScheduler.schedule(after: .seconds(0), interval: .seconds(2)) { values.append(42) }

    XCTAssertEqual(values, [])
    testScheduler.advance()
    XCTAssertEqual(values, [1, 42])
    testScheduler.advance(by: .seconds(2))
    XCTAssertEqual(values, [1, 42, 1, 42, 1])
  }

  func testLongLivingEffects() {
    typealias Environment = (
      startEffect: Effect<Void, Never>,
      stopEffect: Effect<Never, Never>
    )

    enum Action { case end, incr, start }

    let reducer = Reducer<Int, Action, Environment> { state, action, environment in
      switch action {
      case .end:
        return environment.stopEffect.fireAndForget()
      case .incr:
        state += 1
        return .none
      case .start:
        return environment.startEffect.map { Action.incr }
      }
    }

    let subject = Signal<Void, Never>.pipe()

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: (
        startEffect: subject.output.producer,
        stopEffect: .fireAndForget { subject.input.sendCompleted() }
      )
    )

    store.assert(
      .send(.start),
      .send(.incr) { $0 = 1 },
      .do { subject.input.send(value: ()) },
      .receive(.incr) { $0 = 2 },
      .send(.end)
    )
  }

  func testCancellation() {
    enum Action: Equatable {
      case cancel
      case incr
      case response(Int)
    }

    struct Environment {
      let fetch: (Int) -> Effect<Int, Never>
      let mainQueue: DateScheduler
    }

    let reducer = Reducer<Int, Action, Environment> { state, action, environment in
      struct CancelId: Hashable {}

      switch action {
      case .cancel:
        return .cancel(id: CancelId())

      case .incr:
        state += 1
        return environment.fetch(state)
          .observe(on: environment.mainQueue)
          .map(Action.response)
          .cancellable(id: CancelId())

      case let .response(value):
        state = value
        return .none
      }
    }

    let scheduler = TestScheduler()

    let store = TestStore(
      initialState: 0,
      reducer: reducer,
      environment: Environment(
        fetch: { value in Effect(value: value * value) },
        mainQueue: scheduler
      )
    )

    store.assert(
      .send(.incr) { $0 = 1 },
      .do { scheduler.advance() },
      .receive(.response(1)) { $0 = 1 }
    )

    store.assert(
      .send(.incr) { $0 = 2 },
      .send(.cancel),
      .do { scheduler.run() }
    )
  }
}
