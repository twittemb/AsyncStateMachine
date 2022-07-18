//
//  Producer.swift
//  
//
//  Created by Thibault WITTEMBERG on 19/07/2022.
//

struct Producer<Element>: Sendable
where Element: Sendable {
  let continuation: UnsafeContinuation<Consumer<Element>?, Never>?
}
