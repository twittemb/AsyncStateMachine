//
//  Task+ForEver.swift
//  
//
//  Created by Thibault WITTEMBERG on 09/07/2022.
//

extension Task where Success == Void, Failure == Never {
  static func forEver(
    execute: @Sendable @escaping () -> Void,
    onCancel: @Sendable @escaping () -> Void = {}
  ) -> Task<Success, Failure> {
    Task {
      await withTaskCancellationHandler {
        await withUnsafeContinuation { continuation in
          execute()
        }
      } onCancel: {
        onCancel()
      }
    }
  }
}
