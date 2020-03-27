import CasePaths
import Combine
import XCTest
@testable import CompArch

final class CompArchTests: XCTestCase {
    func test_matchingIndexed() {
        let reducer: Reducer<IndexedParent.State, IndexedParent.Action, Void> = { state, action, _ in
            switch action {
                case let .child((index, .childAction1)):
                    return [
                        Just(.childAction(index))
                            .eraseToEffect()
                ]
                case .child(_):
                    return []
                case .childAction(_):
                    return []
            }
        }
        var parent = IndexedParent.State(parentProp: 0)
        let effects = reducer(&parent, .child(Indexed(1, .childAction1)), ())
        XCTAssertEqual(effects.count, 1)

        let exp = expectation(description: "exp")
        let effect = effects[0]
        let _ = effect.sink { action in
            if case let .childAction(index) = action {
                XCTAssertEqual(index, 1)
            } else {
                XCTFail("failed to extract index from childAction")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    func test_matchingIdentified() {
        let reducer: Reducer<IdentifiedParent.State, IdentifiedParent.Action, Void> = { state, action, _ in
            switch action {
                case let .child((id, .childAction1)):
                    return [
                        Just(.childAction(id))
                            .eraseToEffect()
                ]
                case .child(_):
                    return []
                case .childAction(_):
                    return []
            }
        }
        var parent = IdentifiedParent.State(parentProp: 0)
        let action = Identified<Child.State, Child.Action>(id: 1, action: .childAction1)
        let effects = reducer(&parent, .child(action), ())
        XCTAssertEqual(effects.count, 1)

        let exp = expectation(description: "exp")
        let effect = effects[0]
        let _ = effect.sink { action in
            if case let .childAction(index) = action {
                XCTAssertEqual(index, 1)
            } else {
                XCTFail("failed to extract index from childAction")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }
}


struct IndexedParent {
    struct State {
        var parentProp: Int
    }

    enum Action {
        case child(Indexed<Child.Action>)
        case childAction(Int)
    }
}


struct IdentifiedParent {
    struct State {
        var parentProp: Int
    }

    enum Action {
        case child(Identified<Child.State, Child.Action>)
        case childAction(Child.State.ID)
    }
}


struct Child {
    struct State: Identifiable {
        var id: Int { childProp }
        var childProp: Int
    }

    enum Action {
        case childAction1
        case childAction2
    }
}
