import Foundation

public enum SpeedProfile {
    public static let acceleration = 0.6
    public static let braking = 0.7

    public static func distance(length d: Double, duration t: Double, elapsed: Double) -> (metres: Double, speed: Double) {
        guard t > 0, d > 0 else { return (d, 0) }
        let tau = min(t, max(0, elapsed))
        let k = 1 / acceleration + 1 / braking
        let discriminant = t * t - 2 * d * k
        if discriminant < 0 {
            let a = 4 * d / (t * t)
            let half = t / 2
            return tau < half
                ? (0.5 * a * tau * tau, a * tau)
                : (d - 0.5 * a * (t - tau) * (t - tau), a * (t - tau))
        }
        let cruise = (t - discriminant.squareRoot()) / k
        let accelerationTime = cruise / acceleration
        let brakingTime = cruise / braking
        if tau < accelerationTime { return (0.5 * acceleration * tau * tau, acceleration * tau) }
        if tau > t - brakingTime {
            let left = t - tau
            return (d - 0.5 * braking * left * left, braking * left)
        }
        return (0.5 * acceleration * accelerationTime * accelerationTime + cruise * (tau - accelerationTime), cruise)
    }
}
