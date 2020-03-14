//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 14/03/2020.
//

import CasePaths
import SwiftUI


extension Store {
    // https://twitter.com/alexito4/status/1228373956777979905?s=21
    public func binding<T>(value: KeyPath<Value, T>,
                           action: CasePath<Action, T>) -> Binding<T> {
        Binding<T>(
            get: { self.value[keyPath: value]  },
            set: { self.send(action.embed($0)) }
        )
    }
}

