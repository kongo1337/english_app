import Foundation

public enum SwipeDirection: Equatable, Sendable { case left, right }

/// Turns a drag of the card into a decision. In the Learn tab right = learned and left =
/// still learning; in the Review tab right = remembered and left = forgot.
public enum SwipeDecision {
    /// The card counts as thrown once it is dragged this far…
    public static let distanceThreshold: CGFloat = 100
    /// …or when a quick flick would carry it this far (`predictedEndTranslation`).
    public static let flickThreshold: CGFloat = 300
    /// A flick must at least start moving.
    public static let flickMinimumDistance: CGFloat = 30
    public static let maxRotation: Double = 12

    public static func direction(forWidth width: CGFloat, predictedEndWidth: CGFloat) -> SwipeDirection? {
        if abs(width) >= distanceThreshold {
            return width > 0 ? .right : .left
        }
        let sameDirection = (width > 0) == (predictedEndWidth > 0)
        if abs(width) >= flickMinimumDistance, sameDirection, abs(predictedEndWidth) >= flickThreshold {
            return width > 0 ? .right : .left
        }
        return nil
    }

    /// 0 at rest, 1 once the threshold is reached: drives the opacity of the hint label.
    public static func hintProgress(forWidth width: CGFloat) -> Double {
        Double(min(1, abs(width) / distanceThreshold))
    }

    /// Tilt of the card while it is dragged, up to ±12°.
    public static func rotation(forWidth width: CGFloat) -> Double {
        max(-maxRotation, min(maxRotation, Double(width) / 20))
    }
}
