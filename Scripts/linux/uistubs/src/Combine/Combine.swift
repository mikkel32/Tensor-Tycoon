// Minimal stub of Combine: just enough for `onReceive(_:perform:)` with Foundation's notification publisher.
import Foundation

public protocol Publisher<Output, Failure> {
    associatedtype Output
    associatedtype Failure: Error
}

public protocol Cancellable { func cancel() }

public final class AnyCancellable: Cancellable, Hashable {
    public init(_ cancel: @escaping () -> Void) {}
    public init<C: Cancellable>(_ canceller: C) {}
    public func cancel() {}
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool { lhs === rhs }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

public struct Just<Output>: Publisher {
    public typealias Failure = Never
    public let output: Output
    public init(_ output: Output) { self.output = output }
}

public struct Empty<Output, Failure: Error>: Publisher {
    public init(completeImmediately: Bool = true) {}
}

// On Darwin these live in the Foundation overlay (which imports Combine). Linux's Foundation has no Combine, so the
// stub hosts them here; they are visible to any module that (transitively) imports SwiftUI.
extension NotificationCenter {
    public struct Publisher: Combine.Publisher {
        public typealias Output = Notification
        public typealias Failure = Never
        public let center: NotificationCenter
        public let name: Notification.Name
        public let object: AnyObject?
        public init(center: NotificationCenter, name: Notification.Name, object: AnyObject? = nil) {
            self.center = center; self.name = name; self.object = object
        }
    }
    public func publisher(for name: Notification.Name, object: AnyObject? = nil) -> NotificationCenter.Publisher {
        NotificationCenter.Publisher(center: self, name: name, object: object)
    }
}

extension Timer {
    public final class TimerPublisher: Combine.Publisher {
        public typealias Output = Date
        public typealias Failure = Never
        internal init() {}
        public func autoconnect() -> TimerPublisher { self }
    }
    public static func publish(every interval: TimeInterval, tolerance: TimeInterval? = nil, on runLoop: RunLoop,
                               in mode: RunLoop.Mode, options: RunLoop.SchedulerOptions? = nil) -> Timer.TimerPublisher {
        TimerPublisher()
    }
}

extension RunLoop { public struct SchedulerOptions: Sendable {} }
