//
//  DSLCompatible.swift
//
//
//  Created by Thibault WITTEMBERG on 25/06/2022.
//

// insppired by https://github.com/gringoireDM/EnumKit
import Foundation

/// ``DSLCompatible`` conformance allows enum types to be
/// used in a declarative fashion by using memory fingerprint comparition
/// or case label comparition.
///
/// ```
/// enum Value: DSLCompatible {
///   case v1
///   case v2(value: String)
/// }
///
/// let me = Value.v2("foo")
///
/// me.matches(Value.v2(value:)) // true
/// me.matches(Value.v1) // false
///
/// me.associatedValue(expecting: String.self) // returns "foo"?
/// me.associatedValue(expecting: Int.self) // returns nil
/// ```
public protocol DSLCompatible {}

struct NotAnEnumError: Error {}

public extension DSLCompatible {
  /// if Self is an enum: returns the label of the case
  /// if Self is a type with some properties: returns the label of the first property
  /// if Self is a type without properties: returns the description of the type
  var label: String {
    return Mirror(reflecting: self).children.first?.label ?? String(describing: self)
  }

  /// Determines if `self` matches an enum case from a memory fingerprint perspective or a label perspective.
  ///
  /// ```
  /// enum Value: DSLCompatible {
  ///   case v1
  ///   case v2
  /// }
  ///
  /// let me = Value.v2
  ///
  /// me.matches(Value.v2) // true
  /// me.matches(Value.v1) // false
  /// ```
  ///
  /// - Parameter other: the value against which we are looking for a match.
  /// - Returns: true when `other` matches `self`, false otherwise,
  func matches(_ other: Self) -> Bool {
    var me = self
    var other = other
    // compare memory bitwise (should be the priviledged comparaison point)
    return memcmp(&me, &other, MemoryLayout<Self>.size) == 0 || me.label == other.label
  }


  /// Determines if `self` matches an enum case signature that has associated values.
  ///
  /// ```
  /// enum Value: DSLCompatible {
  ///   case v1(value: Int)
  ///   case v2(value: String)
  /// }
  ///
  /// let me = Value.v2(value: "foo")
  ///
  /// me.matches(Value.v2(value:)) // true
  /// me.matches(Value.v1(value:)) // false
  /// ```
  ///
  /// - Parameter definition: the signature of the enum case
  /// - Returns: true when self matches the `definition`, false otherwise,
  func matches<AssociatedValue>(_ definition: (AssociatedValue) -> Self) -> Bool {
    return associatedValue(matching: definition) != nil
  }

  /// Extracts the associated value from `self` when `self` is an enum case with associated values of the expected type.
  /// - Parameter expecting: the expected type of the associated value.
  /// - Returns: the value of the associated type when the expected type matches the actual associated value, nil otherwise.
  func associatedValue<AssociatedValue>(expecting: AssociatedValue.Type) -> AssociatedValue? {
    return decompose(expecting: expecting)?.associatedValue
  }

  /// Extracts the associated value from `self` when `self` is an enum case that matches the given enum case signature.
  /// - Parameter definition: the signature of the enum case
  /// - Returns: the value of the associated type when `self` matches the given enum signature, nil otherwise.
  func associatedValue<AssociatedValue>(matching definition: (AssociatedValue) -> Self) -> AssociatedValue? {
    guard
      let me: (path: [String?], associatedValue: AssociatedValue) = decompose(expecting: AssociatedValue.self),
      let other: (path: [String?], associatedValue: AssociatedValue) = definition(me.associatedValue).decompose(expecting: AssociatedValue.self),
      me.path == other.path else { return nil }
    return me.associatedValue
  }
}

extension DSLCompatible {
  func decompose<AssociatedValue>(
    expecting: AssociatedValue.Type
  ) -> (path: [String?], associatedValue: AssociatedValue)? {
    let mirror = Mirror(reflecting: self)

    guard mirror.displayStyle == .enum else { return nil }

    var path: [String?] = []
    var any: Any = self

    while case let (label?, anyChild)? = Mirror(reflecting: any).children.first {
      path.append(label)
      path.append(String(describing: type(of: anyChild)))
      if let child = anyChild as? AssociatedValue { return (path, child) }
      any = anyChild
    }
    if MemoryLayout<AssociatedValue>.size == 0 {
      return (["\(self)"], unsafeBitCast((), to: AssociatedValue.self))
    }
    return nil
  }
}
