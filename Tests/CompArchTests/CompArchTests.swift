import CasePaths
import Combine
import XCTest
@testable import CompArch

final class CompArchTests: XCTestCase {
    func test_matchingIndexed() {
        let reducer: Reducer<Parent.State, Parent.Action> = { state, action in
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
        var parent = Parent.State(parentProp: 0)
        let effects = reducer(&parent, .child(Indexed(1, .childAction1)))
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


struct Parent {
    struct State {
        var parentProp: Int
    }

    enum Action {
        case child(Indexed<Child.Action>)
        case childAction(Int)
    }
}


struct Child {
    struct State {
        var id: Int { childProp }
        var childProp: Int
    }

    enum Action {
        case childAction1
        case childAction2
    }
}
