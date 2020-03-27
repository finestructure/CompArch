//
//  Store.swift
//  CompArch
//
//  Created by Sven A. Schmidt on 22/01/2020.
//  Copyright © 2020 finestructure. All rights reserved.
//

import CasePaths
import Combine


public typealias Reducer<Value, Action, Environment> = (inout Value, Action, Environment) -> [Effect<Action>]


public final class Store<Value, Action>: ObservableObject {
    @Published public private(set) var value: Value
    private let reducer: (inout Value, Action) -> [Effect<Action>]
    private var viewCancellable: Cancellable?
    private var effectCancellables: Set<AnyCancellable> = []

    public init<Environment>(initialValue: Value,
                             reducer: @escaping Reducer<Value, Action, Environment>,
                             environment: Environment) {
        self.value = initialValue
        self.reducer = { value, action in
            reducer(&value, action, environment)
        }
    }

    public func send(_ action: Action) {
        let effects = reducer(&value, action)
        effects.forEach { effect in
            var effectCancellable: AnyCancellable?
            var didComplete = false
            effectCancellable = effect.sink(
              receiveCompletion: { [weak self, weak effectCancellable] _ in
                didComplete = true
                guard let effectCancellable = effectCancellable else { return }
                self?.effectCancellables.remove(effectCancellable)
              },
              receiveValue: { [weak self] in self?.send($0) }
            )
            if !didComplete, let effectCancellable = effectCancellable {
              effectCancellables.insert(effectCancellable)
            }
        }
    }

    public func view<LocalValue, LocalAction>(
        value toLocalValue: @escaping (Value) -> LocalValue,
        action toGlobalAction: @escaping (LocalAction) -> Action
    ) -> Store<LocalValue, LocalAction> {
        let localStore = Store<LocalValue, LocalAction>(
            initialValue: toLocalValue(self.value),
            reducer: { localValue, localAction, _ in
                self.send(toGlobalAction(localAction))
                localValue = toLocalValue(self.value)
                return []
        },
            environment: ()
        )
        localStore.viewCancellable = self.$value.sink { [weak localStore] newValue in
            localStore?.value = toLocalValue(newValue)
        }
        return localStore
    }
}


public func combine<Value, Action, Environment>(_ reducers: Reducer<Value, Action, Environment>...)
    -> Reducer<Value, Action, Environment> {

    return { value, action, environment in
        let effects = reducers.flatMap { $0(&value, action, environment) }
        return effects
    }
}


public func pullback<GlobalValue, LocalValue, GlobalAction, LocalAction, LocalEnvironment, GlobalEnvironment>(
  _ reducer: @escaping Reducer<LocalValue, LocalAction, LocalEnvironment>,
  value: WritableKeyPath<GlobalValue, LocalValue>,
  action: WritableKeyPath<GlobalAction, LocalAction?>,
  environment: @escaping (GlobalEnvironment) -> LocalEnvironment
) -> Reducer<GlobalValue, GlobalAction, GlobalEnvironment> {

    return { globalValue, globalAction, globalEnvironment in
        guard let localAction = globalAction[keyPath: action] else { return [] }
        let localEffects = reducer(&globalValue[keyPath: value], localAction, environment(globalEnvironment))
        return localEffects.map { localEffect in
            localEffect.map { localAction -> GlobalAction in
                var globalAction = globalAction
                globalAction[keyPath: action] = localAction
                return globalAction
            }.eraseToEffect()
        }
    }
}


public func pullback<GlobalValue, LocalValue, GlobalAction, LocalAction, LocalEnvironment, GlobalEnvironment>(
  _ reducer: @escaping Reducer<LocalValue, LocalAction, LocalEnvironment>,
  value: WritableKeyPath<GlobalValue, LocalValue>,
  action: CasePath<GlobalAction, LocalAction>,
  environment: @escaping (GlobalEnvironment) -> LocalEnvironment
) -> Reducer<GlobalValue, GlobalAction, GlobalEnvironment> {

    return { globalValue, globalAction, globalEnvironment in
        guard let localAction = action.extract(from: globalAction) else { return [] }
        let localEffects = reducer(&globalValue[keyPath: value], localAction, environment(globalEnvironment))
        return localEffects.map {
            $0.map(action.embed).eraseToEffect()
        }
    }
}


public func logging<Value, Action, Environment>(_ reducer: @escaping Reducer<Value, Action, Environment>)
    -> Reducer<Value, Action, Environment> {

        return { value, action, environment in
        let effects = reducer(&value, action, environment)
        let newValue = value
        return [.fireAndForget {
            print("Action: \(action)")
            print("State:")
            dump(newValue)
            print("---")
              }] + effects
    }
}


// See https://github.com/pointfreeco/episode-code-samples/issues/33 for details

public typealias Indexed<Action> = (index: Int, action: Action)


public func indexed<State, Action, Environment, GlobalState, GlobalAction, GlobalEnvironment>(
    reducer: @escaping Reducer<State, Action, Environment>,
    _ value: WritableKeyPath<GlobalState, [State]>,
    _ action: CasePath<GlobalAction, Indexed<Action>>,
    _ environment: @escaping (GlobalEnvironment) -> Environment
) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    return { globalValue, globalAction, globalEnvironment in
        guard let localAction = action.extract(from: globalAction) else { return [] }
        let index = localAction.index
        let localEffects = reducer(&globalValue[keyPath: value][index], localAction.action, environment(globalEnvironment))
        return localEffects.map { localEffect in
            localEffect.map { localAction in
                action.embed(Indexed(index: index, action: localAction))
            }.eraseToEffect()
        }
    }
}


public typealias Identified<Value: Identifiable, Action> = (id: Value.ID, action: Action)


public func identified<State: Identifiable, Action, Environment, GlobalState, GlobalAction, GlobalEnvironment>(
    reducer: @escaping Reducer<State, Action, Environment>,
    _ value: WritableKeyPath<GlobalState, [State]>,
    _ action: CasePath<GlobalAction, Identified<State, Action>>,
    _ environment: @escaping (GlobalEnvironment) -> Environment
) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    return { globalValue, globalAction, globalEnvironment in
        guard let localAction = action.extract(from: globalAction) else { return [] }
        let id = localAction.id
        guard let index = globalValue[keyPath: value].firstIndex(where: { $0.id == id }) else { return [] }
        let localEffects = reducer(&globalValue[keyPath: value][index], localAction.action, environment(globalEnvironment))
        return localEffects.map { localEffect in
            localEffect.map { localAction in
                action.embed(Identified<State, Action>(id: id, action: localAction))
            }.eraseToEffect()
        }
    }
}


// Moritz Lang:
// https://github.com/pointfreeco/episode-code-samples/issues/33#issuecomment-599794433
extension Store {
    public func view<LocalValue: Identifiable, LocalAction>(
        _ array: WritableKeyPath<Value, [LocalValue]>,
        id: LocalValue.ID,
        action: CasePath<Action, Identified<LocalValue, LocalAction>>
    ) -> Store<LocalValue, LocalAction> {
        view(
            value: { (value: Value) in value[keyPath: array].first(where: { $0.id == id })! },
            action: { action.embed((id, action: $0)) }
        )
    }
}
