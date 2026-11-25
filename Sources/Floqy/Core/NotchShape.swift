import SwiftUI

/// Hardware-authentic notch silhouette with concave top ears and rounded bottom corners.
struct NotchShellShape: Shape {
    var topEarRadius: CGFloat = NotchGeometry.earWidth
    var bottomCornerRadius: CGFloat
    var taperedChinInset: CGFloat = 0
    var leftLeadingInset: CGFloat = 0
    var cameraHeight: CGFloat = 34

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(topEarRadius, bottomCornerRadius),
                AnimatablePair(taperedChinInset, leftLeadingInset)
            )
        }
        set {
            topEarRadius = newValue.first.first
            bottomCornerRadius = newValue.first.second
            taperedChinInset = newValue.second.first
            leftLeadingInset = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let ear = max(0, min(topEarRadius, rect.width / 4, rect.height / 2))
        let leftInnerX = rect.minX + ear
        let rightInnerX = rect.maxX - ear

        // Use a tapered central mini-chin when extending below the camera bezel in idle mode.
        let maxInset = max(0, (rightInnerX - leftInnerX - 44) / 2)
        let inset = min(max(0, taperedChinInset), maxInset)
        let camH = min(max(cameraHeight, ear + 4), rect.height - 6)

        if inset > 0.5 && rect.height > camH + 2 {
            let shoulder = min(6, inset / 2, (rect.height - camH) / 2)
            let camCorner = min(8, inset / 2, max(0, camH - ear))
            let chinLeftX = leftInnerX + inset
            let chinRightX = rightInnerX - inset
            let bottom = max(
                0,
                min(bottomCornerRadius, (chinRightX - chinLeftX) / 2, rect.maxY - (rect.minY + camH + shoulder))
            )

            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            if ear > 0.1 {
                path.addQuadCurve(
                    to: CGPoint(x: rightInnerX, y: rect.minY + ear),
                    control: CGPoint(x: rightInnerX, y: rect.minY)
                )
            }

            path.addLine(to: CGPoint(x: rightInnerX, y: rect.minY + camH - camCorner))
            path.addQuadCurve(
                to: CGPoint(x: rightInnerX - camCorner, y: rect.minY + camH),
                control: CGPoint(x: rightInnerX, y: rect.minY + camH)
            )
            path.addLine(to: CGPoint(x: chinRightX + shoulder, y: rect.minY + camH))
            path.addQuadCurve(
                to: CGPoint(x: chinRightX, y: rect.minY + camH + shoulder),
                control: CGPoint(x: chinRightX, y: rect.minY + camH)
            )

            path.addLine(to: CGPoint(x: chinRightX, y: rect.maxY - bottom))
            path.addQuadCurve(
                to: CGPoint(x: chinRightX - bottom, y: rect.maxY),
                control: CGPoint(x: chinRightX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: chinLeftX + bottom, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: chinLeftX, y: rect.maxY - bottom),
                control: CGPoint(x: chinLeftX, y: rect.maxY)
            )

            path.addLine(to: CGPoint(x: chinLeftX, y: rect.minY + camH + shoulder))
            path.addQuadCurve(
                to: CGPoint(x: chinLeftX - shoulder, y: rect.minY + camH),
                control: CGPoint(x: chinLeftX, y: rect.minY + camH)
            )
            path.addLine(to: CGPoint(x: leftInnerX + camCorner, y: rect.minY + camH))
            path.addQuadCurve(
                to: CGPoint(x: leftInnerX, y: rect.minY + camH - camCorner),
                control: CGPoint(x: leftInnerX, y: rect.minY + camH)
            )

            if ear > 0.1 {
                path.addLine(to: CGPoint(x: leftInnerX, y: rect.minY + ear))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.minY),
                    control: CGPoint(x: leftInnerX, y: rect.minY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            }

            path.closeSubpath()
            return path
        }

        let lead = max(0, min(leftLeadingInset, max(0, rect.width - ear - 44)))
        let leftOuterX = rect.minX + lead
        let leftEar: CGFloat = ear > 0 ? ear * max(0, 1 - lead / ear) : 0
        let standardLeftInnerX = leftOuterX + leftEar
        let bottom = max(
            0,
            min(bottomCornerRadius, (rightInnerX - standardLeftInnerX) / 2, rect.height - max(ear, leftEar))
        )

        // Start at top-left edge (inset when only a right wing is active)
        path.move(to: CGPoint(x: leftOuterX, y: rect.minY))
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
        path.addLine(to: CGPoint(x: standardLeftInnerX + bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: standardLeftInnerX, y: rect.maxY - bottom),
            control: CGPoint(x: standardLeftInnerX, y: rect.maxY)
        )

        // Left vertical edge up to left concave ear (or flush camera edge when lead > 0)
        path.addLine(to: CGPoint(x: standardLeftInnerX, y: rect.minY + leftEar))
        if leftEar > 0.1 {
            path.addQuadCurve(
                to: CGPoint(x: leftOuterX, y: rect.minY),
                control: CGPoint(x: standardLeftInnerX, y: rect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: leftOuterX, y: rect.minY))
        }

        path.closeSubpath()
        return path
    }
}
