// Stub of the Symbols framework (SF Symbol effects), used by SwiftUI's `symbolEffect` modifiers.
// DELIBERATE RELAXATION: effect types expose a simplified set of variants (`.byLayer`, `.up`, …) and protocols.

public protocol SymbolEffect: Sendable {}
public protocol IndefiniteSymbolEffect {}
public protocol DiscreteSymbolEffect {}
public protocol TransitionSymbolEffect {}
public protocol ContentTransitionSymbolEffect {}

public struct SymbolEffectOptions: Equatable, Sendable {
    public static var `default`: SymbolEffectOptions { .init() }
    public static var `repeating`: SymbolEffectOptions { .init() }
    public static var nonRepeating: SymbolEffectOptions { .init() }
    public static func `repeat`(_ count: Int?) -> SymbolEffectOptions { .init() }
    public static func speed(_ speed: Double) -> SymbolEffectOptions { .init() }
    public func `repeat`(_ count: Int?) -> SymbolEffectOptions { self }
    public func speed(_ speed: Double) -> SymbolEffectOptions { self }
}

public struct PulseSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {
    public var byLayer: PulseSymbolEffect { self }
    public var wholeSymbol: PulseSymbolEffect { self }
}
public struct BounceSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {
    public var up: BounceSymbolEffect { self }
    public var down: BounceSymbolEffect { self }
    public var byLayer: BounceSymbolEffect { self }
    public var wholeSymbol: BounceSymbolEffect { self }
}
public struct VariableColorSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {
    public var iterative: VariableColorSymbolEffect { self }
    public var cumulative: VariableColorSymbolEffect { self }
    public var reversing: VariableColorSymbolEffect { self }
}
public struct ScaleSymbolEffect: SymbolEffect, IndefiniteSymbolEffect {
    public var up: ScaleSymbolEffect { self }
    public var down: ScaleSymbolEffect { self }
}
public struct WiggleSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {}
public struct RotateSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {}
public struct BreatheSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {}
public struct ReplaceSymbolEffect: SymbolEffect, ContentTransitionSymbolEffect {}
public struct AppearSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, TransitionSymbolEffect {}
public struct DisappearSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, TransitionSymbolEffect {}

extension SymbolEffect where Self == PulseSymbolEffect { public static var pulse: PulseSymbolEffect { .init() } }
extension SymbolEffect where Self == BounceSymbolEffect { public static var bounce: BounceSymbolEffect { .init() } }
extension SymbolEffect where Self == VariableColorSymbolEffect { public static var variableColor: VariableColorSymbolEffect { .init() } }
extension SymbolEffect where Self == ScaleSymbolEffect { public static var scale: ScaleSymbolEffect { .init() } }
extension SymbolEffect where Self == WiggleSymbolEffect { public static var wiggle: WiggleSymbolEffect { .init() } }
extension SymbolEffect where Self == RotateSymbolEffect { public static var rotate: RotateSymbolEffect { .init() } }
extension SymbolEffect where Self == BreatheSymbolEffect { public static var breathe: BreatheSymbolEffect { .init() } }
extension SymbolEffect where Self == ReplaceSymbolEffect { public static var replace: ReplaceSymbolEffect { .init() } }
extension SymbolEffect where Self == AppearSymbolEffect { public static var appear: AppearSymbolEffect { .init() } }
extension SymbolEffect where Self == DisappearSymbolEffect { public static var disappear: DisappearSymbolEffect { .init() } }
