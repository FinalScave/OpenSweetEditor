import Foundation

enum CoreAnimationScheduler {
    static let frameInterval: TimeInterval = 1.0 / 60.0

    static func schedule(_ timer: inout Timer?,
                         delayMs: Int32,
                         action: @escaping () -> Void) {
        timer?.invalidate()
        let interval = delayMs <= 0
            ? frameInterval
            : TimeInterval(delayMs) / 1000.0
        let newTimer = Timer(timeInterval: interval, repeats: false) { _ in
            action()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
}
