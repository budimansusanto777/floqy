import SwiftUI

enum AIPetPhase: Equatable {
    case working
    case permission
    case done
}

/// Compact animated pixel companion per AI agent (Claude coral sprite, Antigravity cyan bot, Gemini star-bot).
struct FloqyAIPetSpriteView: View {
    let agent: AIAgentKind
    let phase: AIPetPhase
    var size: CGFloat = 22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func accentColor(for agent: AIAgentKind) -> Color {
        switch agent {
        case .claudeCode, .claudeDesktop:
            return Color(red: 249 / 255, green: 115 / 255, blue: 98 / 255)
        case .antigravity:
            return NotchColors.accentPrimary
        case .geminiCLI:
            return NotchColors.statusHealthy
        }
    }

    private var darkBodyColor: Color {
        switch agent {
        case .claudeCode, .claudeDesktop:
            return Color(red: 194 / 255, green: 65 / 255, blue: 12 / 255)
        case .antigravity:
            return Color(red: 2 / 255, green: 132 / 255, blue: 199 / 255)
        case .geminiCLI:
            return Color(red: 5 / 255, green: 150 / 255, blue: 105 / 255)
        }
    }

    var body: some View {
        let animate = !reduceMotion
        let canvasWidth = round(size * (32.0 / 24.0))
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !animate)) { context in
            let t = animate ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, canvasSize in
                drawSprite(in: &ctx, size: canvasSize, time: t)
            }
        }
        .frame(width: canvasWidth, height: size)
        .accessibilityHidden(true)
    }

    private func drawSprite(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let sx = size.width / 32.0
        let sy = size.height / 24.0
        let accent = Self.accentColor(for: agent)
        let dark = darkBodyColor
        let ink = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)

        let hopY: CGFloat = switch phase {
        case .working:
            reduceMotion ? 0 : CGFloat(-abs(sin(time * 5.0))) * 1.4
        case .done:
            reduceMotion ? 0 : CGFloat(-abs(sin(time * 6.2))) * 2.1
        case .permission:
            0
        }

        func fillRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 0, color: Color, dy: CGFloat = hopY) {
            let rect = CGRect(x: x * sx, y: (y + dy) * sy, width: w * sx, height: h * sy)
            let path = radius > 0
                ? Path(roundedRect: rect, cornerRadius: radius * min(sx, sy))
                : Path(rect)
            context.fill(path, with: .color(color))
        }

        // Character silhouette
        switch agent {
        case .claudeCode, .claudeDesktop:
            fillRect(5, 6, 16, 11, radius: 1.5, color: accent)
            fillRect(2.5, 10, 2.5, 3.5, color: accent)
            fillRect(21, 10, 2.5, 3.5, color: accent)
            fillRect(6, 17, 2.5, 4, color: dark)
            fillRect(10, 17, 2.5, 4, color: accent)
            fillRect(13.5, 17, 2.5, 4, color: accent)
            fillRect(17.5, 17, 2.5, 4, color: dark)

        case .antigravity:
            fillRect(12, 2.5, 2, 3, color: Color(red: 186 / 255, green: 230 / 255, blue: 253 / 255))
            let orb = CGRect(x: 11.4 * sx, y: (1.0 + hopY) * sy, width: 3.2 * sx, height: 3.2 * sy)
            context.fill(Path(ellipseIn: orb), with: .color(accent))
            fillRect(5, 5.5, 16, 11.5, radius: 3.0, color: accent)
            fillRect(7, 8, 12, 6, radius: 1.4, color: Color(red: 224 / 255, green: 242 / 255, blue: 254 / 255))
            fillRect(7.5, 17, 3, 3.8, radius: 1, color: dark)
            fillRect(15.5, 17, 3, 3.8, radius: 1, color: dark)

        case .geminiCLI:
            fillRect(5.5, 5.5, 15, 11.5, radius: 3.5, color: accent)
            fillRect(7.5, 8, 11, 5.8, radius: 1.5, color: Color(red: 209 / 255, green: 250 / 255, blue: 229 / 255))
            fillRect(8, 17, 3, 3.6, radius: 1, color: dark)
            fillRect(15, 17, 3, 3.6, radius: 1, color: dark)
        }

        // Eyes by state
        if phase == .done {
            var leftEye = Path()
            leftEye.move(to: CGPoint(x: 8.5 * sx, y: (11.5 + hopY) * sy))
            leftEye.addLine(to: CGPoint(x: 10.0 * sx, y: (9.7 + hopY) * sy))
            leftEye.addLine(to: CGPoint(x: 11.5 * sx, y: (11.5 + hopY) * sy))
            var rightEye = Path()
            rightEye.move(to: CGPoint(x: 14.5 * sx, y: (11.5 + hopY) * sy))
            rightEye.addLine(to: CGPoint(x: 16.0 * sx, y: (9.7 + hopY) * sy))
            rightEye.addLine(to: CGPoint(x: 17.5 * sx, y: (11.5 + hopY) * sy))
            let eyeStroke = StrokeStyle(lineWidth: max(1.3, 1.5 * min(sx, sy)), lineCap: .round, lineJoin: .round)
            context.stroke(leftEye, with: .color(ink), style: eyeStroke)
            context.stroke(rightEye, with: .color(ink), style: eyeStroke)
        } else {
            let blink = !reduceMotion && phase == .working && sin(time * 2.1) > 0.96
            let eyeH: CGFloat = blink ? 0.8 : 2.5
            let eyeY: CGFloat = blink ? 10.7 : 9.6
            fillRect(8.8, eyeY, 2.2, eyeH, color: ink)
            fillRect(15.2, eyeY, 2.2, eyeH, color: ink)
        }

        // Action prop by state
        switch phase {
        case .working:
            let swingDeg: CGFloat = reduceMotion ? 10 : CGFloat(sin(time * 9.0)) * 24
            var toolCtx = context
            toolCtx.translateBy(x: 22.5 * sx, y: (15.0 + hopY) * sy)
            toolCtx.rotate(by: .degrees(swingDeg))
            toolCtx.fill(
                Path(roundedRect: CGRect(x: -1.0 * sx, y: -7.5 * sy, width: 2.0 * sx, height: 8.0 * sy), cornerRadius: 0.8 * sx),
                with: .color(Color(red: 203 / 255, green: 213 / 255, blue: 225 / 255))
            )
            toolCtx.fill(
                Path(roundedRect: CGRect(x: -0.5 * sx, y: -9.5 * sy, width: 5.5 * sx, height: 2.6 * sy), cornerRadius: 0.7 * sx),
                with: .color(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))
            )

            // Impact spark pixel when tool reaches bottom of swing
            let sparkVisible = reduceMotion || sin(time * 9.0) > 0.25
            if sparkVisible {
                let yellow = Color(red: 253 / 255, green: 224 / 255, blue: 71 / 255)
                fillRect(24.5, 19.5, 3.2, 1.8, color: yellow, dy: 0)
                fillRect(27.0, 16.5, 1.8, 1.8, color: yellow, dy: 0)
            }

        case .permission:
            let qFloat: CGFloat = reduceMotion ? 0 : CGFloat(sin(time * 4.5)) * 1.1
            let qRect = CGRect(x: 22.5 * sx, y: (1.5 + qFloat) * sy, width: 8.5 * sx, height: 10.5 * sy)
            context.fill(Path(roundedRect: qRect, cornerRadius: 2.5 * sx), with: .color(accent.opacity(0.22)))
            context.draw(
                Text("?")
                    .font(.system(size: max(8.5, 10.5 * min(sx, sy)), weight: .black, design: .monospaced))
                    .foregroundStyle(accent),
                at: CGPoint(x: 26.8 * sx, y: (6.7 + qFloat) * sy),
                anchor: .center
            )

        case .done:
            let waveDeg: CGFloat = reduceMotion ? 0 : CGFloat(sin(time * 7.5)) * 8
            var flagCtx = context
            flagCtx.translateBy(x: 23.5 * sx, y: (18.5 + hopY) * sy)
            flagCtx.rotate(by: .degrees(waveDeg))
            flagCtx.fill(Path(CGRect(x: 0, y: -13.5 * sy, width: 1.5 * sx, height: 13.5 * sy)), with: .color(.white.opacity(0.9)))
            flagCtx.fill(Path(CGRect(x: 1.5 * sx, y: -13.5 * sy, width: 6.2 * sx, height: 4.6 * sy)), with: .color(.white))
            flagCtx.fill(Path(CGRect(x: 1.5 * sx, y: -13.5 * sy, width: 3.1 * sx, height: 2.3 * sy)), with: .color(ink))
            flagCtx.fill(Path(CGRect(x: 4.6 * sx, y: -11.2 * sy, width: 3.1 * sx, height: 2.3 * sy)), with: .color(ink))

            let confetti: [(CGFloat, CGFloat, Color, Double)] = [
                (1.5, 3.0, NotchColors.statusHealthy, 0.0),
                (18.5, 1.5, NotchColors.statusWarning, 1.4),
                (28.0, 12.5, NotchColors.accentPrimary, 2.8)
            ]
            for (cx, cy, cColor, phaseOffset) in confetti {
                let pop: CGFloat = reduceMotion ? 1.0 : CGFloat(0.6 + 0.4 * ((sin(time * 5.2 + phaseOffset) + 1) * 0.5))
                let drift: CGFloat = reduceMotion ? 0 : CGFloat(sin(time * 3.8 + phaseOffset)) * 1.2
                fillRect(cx, cy + drift, 2.2 * pop, 2.2 * pop, color: cColor, dy: 0)
            }
        }
    }
}
