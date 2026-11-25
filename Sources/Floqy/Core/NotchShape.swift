import SwiftUI

/// Hardware-authentic notch silhouette with concave top ears and rounded bottom corners.
struct NotchShellShape: Shape {
    var topEarRadius: CGFloat = NotchGeometry.earWidth
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topEarRadius, bottomCornerRadius) }
        set {
            topEarRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let ear = max(0, min(topEarRadius, rect.width / 4, rect.height / 2))
        let bottom = max(0, min(bottomCornerRadius, (rect.width - ear * 2) / 2, rect.height - ear))

        let leftInnerX = rect.minX + ear
        let rightInnerX = rect.maxX - ear

        // Start at top-left outer tip of the concave ear
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top straight edge across the bezel
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Right concave ear curving downward into the right vertical wall
        path.addQuadCurve(
            to: CGPoint(x: rightInnerX, y: rect.minY + ear),
            control: CGPoint(x: rightInnerX, y: rect.minY)
        )

        // Right vertical edge down to bottom-right corner
        path.addLine(to: CGPoint(x: rightInnerX, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rightInnerX - bottom, y: rect.maxY),
            control: CGPoint(x: rightInnerX, y: rect.maxY)
        )

        // Bottom horizontal edge
        path.addLine(to: CGPoint(x: leftInnerX + bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: leftInnerX, y: rect.maxY - bottom),
            control: CGPoint(x: leftInnerX, y: rect.maxY)
        )

        // Left vertical edge up to left concave ear
        path.addLine(to: CGPoint(x: leftInnerX, y: rect.minY + ear))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: leftInnerX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
