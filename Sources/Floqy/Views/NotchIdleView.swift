import AppKit
import QuartzCore
import SwiftUI

/// Idle notch mini-chin rendering the selected companion and reacting to global pointer motion.
struct NotchIdleView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var productivity: ProductivityService
    @ObservedObject var hardware: HardwareStatusService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var pointerTracker = IdlePointerTracker()
    @State private var isBlinking = false
    @State private var isHappyMood = false
    @State private var gazeOffset: CGSize = .zero
    @State private var petTailAngle: Double = 0
    @State private var petBlink = false
    @State private var petHopOffset: CGFloat = 0
    @State private var petHeadTilt: Double = 0
    @State private var petEyeOffsetX: CGFloat = 0
    @State private var dogFacingLeft = false
    @State private var isPointerActive = false
    @State private var horizonExpanded = false
    @State private var pointerSettleTask: Task<Void, Never>?
    @State private var petBurstTask: Task<Void, Never>?
    @State private var lastPetWakeTime: CFTimeInterval = 0

    private var tracksPointerMotion: Bool {
        guard !reduceMotion else { return false }
        switch manager.idleAppearance {
        case .eyes, .wave, .cat, .dog:
            return true
        case .off, .horizon:
            return false
        }
    }

    private var isSleepyHour: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 22 || hour < 6
    }

    private var horizonColor: Color {
        if productivity.pomodoro.isPaused {
            return NotchColors.focusAccent
        }
        if let battery = hardware.battery, battery.isPluggedIn, battery.percentage >= 95 {
            return NotchColors.statusHealthy
        }
        return NotchColors.textPrimary
    }

    var body: some View {
        Group {
            if manager.idleAppearance == .off {
                Color.clear
            } else if manager.idleAppearance.isSideWing {
                let cameraWidth = manager.geometry.hasHardwareNotch
                    ? manager.geometry.hardwareNotchSize.width
                    : 196
                let leftInset = manager.geometry.leftLeadingInset(
                    for: .idle,
                    idleAppearance: manager.idleAppearance
                )
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: leftInset + cameraWidth)

                    chinContent
                        .frame(width: NotchGeometry.sideWingWidth)
                        .frame(maxHeight: .infinity, alignment: .center)

                    Color.clear
                        .frame(width: NotchGeometry.earWidth)
                }
            } else {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: manager.geometry.notchSafeTopHeight)

                    chinContent
                        .frame(width: manager.idleWidth == .compact ? NotchGeometry.idleChinWidth : nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.bottom, 2)
                }
            }
        }
        .task(id: "\(manager.idleAppearance.rawValue)-\(reduceMotion)") {
            await runIdleAnimationLoop()
        }
        .task(id: manager.idleHappyUntil) {
            await updateHappyWindow()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onAppear {
            configurePointerTracking()
        }
        .onChange(of: manager.idleAppearance) { _, _ in
            configurePointerTracking()
        }
        .onChange(of: reduceMotion) { _, _ in
            configurePointerTracking()
        }
        .onDisappear {
            pointerTracker.setActive(false)
            pointerSettleTask?.cancel()
            pointerSettleTask = nil
            petBurstTask?.cancel()
            petBurstTask = nil
            isPointerActive = false
            gazeOffset = .zero
            resetPetStates()
        }
        .onTapGesture {
            manager.setMode(.expanded)
        }
        .accessibilityElement()
        .accessibilityLabel("Expand Floqy Notch")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var chinContent: some View {
        switch manager.idleAppearance {
        case .off:
            Color.clear
        case .eyes:
            eyesContent
        case .cat:
            MiniCatCompanion(
                tailAngle: reduceMotion ? 0 : petTailAngle,
                blink: !reduceMotion && petBlink,
                headTilt: reduceMotion ? 0 : petHeadTilt,
                eyeOffsetX: reduceMotion ? 0 : petEyeOffsetX,
                hopOffset: reduceMotion ? 0 : petHopOffset
            )
        case .dog:
            MiniDogCompanion(
                tailAngle: reduceMotion ? 0 : petTailAngle,
                blink: !reduceMotion && petBlink,
                headTilt: reduceMotion ? 0 : petHeadTilt,
                hopOffset: reduceMotion ? 0 : petHopOffset,
                facingLeft: !reduceMotion && dogFacingLeft
            )
        case .wave:
            acousticWaveContent
        case .horizon:
            Capsule(style: .continuous)
                .fill(horizonColor)
                .frame(
                    width: (horizonExpanded && !reduceMotion) ? 32 : 26,
                    height: 2.5
                )
                .opacity((horizonExpanded && !reduceMotion) ? 0.88 : 0.56)
        }
    }

    private var eyesContent: some View {
        HStack(spacing: 14) {
            if isHappyMood {
                happyEyeArc
                happyEyeArc
            } else if isSleepyHour {
                sleepyEyeCapsule
                sleepyEyeCapsule
            } else {
                eyeCapsule
                eyeCapsule
            }
        }
        .offset(reduceMotion ? .zero : gazeOffset)
    }

    private var eyeCapsule: some View {
        Capsule(style: .continuous)
            .fill(NotchColors.textPrimary)
            .frame(width: 6.5, height: 10.5)
            .scaleEffect(y: (isBlinking && !reduceMotion) ? 0.14 : 1.0, anchor: .center)
    }

    private var sleepyEyeCapsule: some View {
        Capsule(style: .continuous)
            .fill(NotchColors.textPrimary.opacity(0.78))
            .frame(width: 6.5, height: 3.2)
    }

    private var happyEyeArc: some View {
        HappyEyeArcShape()
            .stroke(
                NotchColors.textPrimary,
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 9, height: 5.5)
    }

    private var acousticWaveContent: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(NotchColors.textPrimary)
                .frame(width: 42, height: 1.8)
                .opacity(isPointerActive && !reduceMotion ? 0 : 0.72)

            if !reduceMotion {
                TimelineView(.animation(paused: !isPointerActive)) { context in
                    DualAcousticWaveCanvas(phase: context.date.timeIntervalSinceReferenceDate * 6.2)
                        .frame(width: 46, height: 12)
                }
                .opacity(isPointerActive ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPointerActive)
    }

    private func resetPetStates() {
        petTailAngle = 0
        petBlink = false
        petHopOffset = 0
        petHeadTilt = 0
        petEyeOffsetX = 0
        dogFacingLeft = false
    }

    private func configurePointerTracking() {
        pointerSettleTask?.cancel()
        pointerSettleTask = nil
        isPointerActive = false
        gazeOffset = .zero
        resetPetStates()

        pointerTracker.onMove = { screenPoint in
            handleGlobalPointerMove(screenPoint)
        }
        pointerTracker.setActive(tracksPointerMotion)
    }

    private func handleGlobalPointerMove(_ screenPoint: CGPoint) {
        guard !reduceMotion else { return }

        let screen = manager.geometry.screenFrame
        let halfW = max(1, screen.width / 2)

        switch manager.idleAppearance {
        case .eyes:
            let height = max(1, screen.height)
            let dx = max(-2.2, min(2.2, ((screenPoint.x - screen.midX) / halfW) * 2.2))
            let dy = max(-0.4, min(1.5, ((screen.maxY - screenPoint.y) / height) * 1.5))
            withAnimation(.easeOut(duration: 0.14)) {
                gazeOffset = CGSize(width: dx, height: dy)
            }
            pointerSettleTask?.cancel()
            pointerSettleTask = Task {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    gazeOffset = .zero
                }
            }

        case .wave:
            if !isPointerActive {
                isPointerActive = true
            }
            pointerSettleTask?.cancel()
            pointerSettleTask = Task {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                isPointerActive = false
            }

        case .cat:
            let eyeDx = max(-1.2, min(1.2, ((screenPoint.x - screen.midX) / halfW) * 1.2))
            withAnimation(.easeOut(duration: 0.16)) {
                petEyeOffsetX = eyeDx
            }
            pointerSettleTask?.cancel()
            pointerSettleTask = Task {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.28)) {
                    petEyeOffsetX = 0
                }
            }

            let now = CACurrentMediaTime()
            guard now - lastPetWakeTime >= 1.4, petBurstTask == nil else { return }
            lastPetWakeTime = now
            petBurstTask = Task {
                await triggerCatPlayfulReaction()
                petBurstTask = nil
            }

        case .dog:
            var turned = false
            if screenPoint.x < screen.midX - 80, !dogFacingLeft {
                withAnimation(.easeInOut(duration: 0.22)) {
                    dogFacingLeft = true
                }
                turned = true
            } else if screenPoint.x > screen.midX + 80, dogFacingLeft {
                withAnimation(.easeInOut(duration: 0.22)) {
                    dogFacingLeft = false
                }
                turned = true
            }

            let now = CACurrentMediaTime()
            guard turned || (now - lastPetWakeTime >= 1.4 && petBurstTask == nil) else { return }
            lastPetWakeTime = now
            petBurstTask?.cancel()
            petBurstTask = Task {
                await triggerDogHappyReaction()
                petBurstTask = nil
            }

        case .off, .horizon:
            break
        }
    }

    private func updateHappyWindow() async {
        guard let happyUntil = manager.idleHappyUntil else {
            isHappyMood = false
            return
        }
        let remaining = happyUntil.timeIntervalSinceNow
        guard remaining > 0 else {
            isHappyMood = false
            return
        }
        isHappyMood = true
        try? await Task.sleep(for: .seconds(remaining))
        if !Task.isCancelled {
            isHappyMood = false
        }
    }

    private func performPetBlink(durationMs: Int) async {
        withAnimation(.easeInOut(duration: 0.08)) {
            petBlink = true
        }
        try? await Task.sleep(for: .milliseconds(durationMs))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.1)) {
            petBlink = false
        }
    }

    private func triggerCatPlayfulReaction() async {
        withAnimation(.easeInOut(duration: 0.22)) {
            petTailAngle = 24
            petHeadTilt = 5.5
            petHopOffset = -0.8
        }
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            petTailAngle = -14
            petHeadTilt = -4.5
            petHopOffset = 0
        }
        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.24)) {
            petTailAngle = 0
            petHeadTilt = 0
        }
    }

    private func triggerDogHappyReaction() async {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
            petHopOffset = -1.6
            petHeadTilt = 4
        }
        for _ in 0..<3 {
            withAnimation(.easeInOut(duration: 0.08)) {
                petTailAngle = 28
            }
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.08)) {
                petTailAngle = -24
            }
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
        }
        withAnimation(.easeOut(duration: 0.16)) {
            petTailAngle = 0
            petHopOffset = 0
            petHeadTilt = 0
        }
    }

    private func runIdleAnimationLoop() async {
        petBurstTask?.cancel()
        petBurstTask = nil
        isBlinking = false
        resetPetStates()
        horizonExpanded = false

        guard !reduceMotion else { return }

        var beat = 0
        switch manager.idleAppearance {
        case .off, .wave:
            return
        case .eyes:
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.4))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.09)) {
                    isBlinking = true
                }
                try? await Task.sleep(for: .milliseconds(110))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.11)) {
                    isBlinking = false
                }
            }
        case .cat:
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { break }
                beat += 1
                if beat.isMultiple(of: 2) {
                    await performPetBlink(durationMs: 120)
                } else if petBurstTask == nil {
                    await triggerCatPlayfulReaction()
                }
            }
        case .dog:
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { break }
                beat += 1
                if beat.isMultiple(of: 2) {
                    await performPetBlink(durationMs: 110)
                } else if petBurstTask == nil {
                    await triggerDogHappyReaction()
                }
            }
        case .horizon:
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 2.0)) {
                    horizonExpanded.toggle()
                }
                try? await Task.sleep(for: .seconds(2.0))
            }
        }
    }
}

/// Observes mouse movement across the screen without requiring Accessibility permissions.
private final class IdlePointerTracker: ObservableObject {
    var onMove: ((CGPoint) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isActive = false
    private var lastEventTime: CFTimeInterval = 0

    deinit {
        stop()
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.emitIfThrottled()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.emitIfThrottled()
            return event
        }
    }

    private func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func emitIfThrottled() {
        let now = CACurrentMediaTime()
        guard now - lastEventTime >= 0.033 else { return }
        lastEventTime = now
        let location = NSEvent.mouseLocation
        onMove?(location)
    }
}

private struct HappyEyeArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.45)
        )
        return path
    }
}

private struct MiniCatCompanion: View {
    let tailAngle: Double
    let blink: Bool
    let headTilt: Double
    let eyeOffsetX: CGFloat
    let hopOffset: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Curled tail extending to the right from the sitting base
            CatTailShape()
                .stroke(
                    NotchColors.textPrimary,
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round)
                )
                .frame(width: 28, height: 15)
                .rotationEffect(.degrees(tailAngle), anchor: UnitPoint(x: 0.64, y: 0.85))

            CatBodyShape()
                .fill(NotchColors.textPrimary)
                .frame(width: 28, height: 15)

            // Crisp dark eyes that follow cursor horizontally and blink periodically
            HStack(spacing: 2.5) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 1.8, height: 1.8)
                    .scaleEffect(y: blink ? 0.2 : 1.0, anchor: .center)
                Circle()
                    .fill(Color.black)
                    .frame(width: 1.8, height: 1.8)
                    .scaleEffect(y: blink ? 0.2 : 1.0, anchor: .center)
            }
            .offset(x: 10.6 + eyeOffsetX, y: 4.9)
        }
        .frame(width: 28, height: 15)
        .rotationEffect(.degrees(headTilt), anchor: .bottom)
        .offset(y: hopOffset)
    }
}

private struct CatBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 28
        let sy = rect.height / 15
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

        var path = Path()
        // Sitting silhouette: rounded haunches + neck + head with two pointed ears
        path.move(to: p(8.2, 14.2))
        path.addQuadCurve(to: p(8.9, 8.8), control: p(7.7, 11.2))
        path.addLine(to: p(8.9, 5.2))
        path.addLine(to: p(8.6, 1.4))
        path.addLine(to: p(11.8, 3.2))
        path.addQuadCurve(to: p(15.2, 3.2), control: p(13.5, 2.7))
        path.addLine(to: p(18.4, 1.4))
        path.addLine(to: p(18.1, 5.2))
        path.addQuadCurve(to: p(16.9, 8.2), control: p(18.4, 7.2))
        path.addQuadCurve(to: p(18.2, 14.2), control: p(18.7, 11.6))
        path.addLine(to: p(8.2, 14.2))
        path.closeSubpath()
        return path
    }
}

private struct CatTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 28
        let sy = rect.height / 15
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

        var path = Path()
        path.move(to: p(17.3, 13.0))
        path.addCurve(to: p(24.8, 6.2), control1: p(21.8, 13.0), control2: p(25.2, 10.2))
        return path
    }
}

private struct MiniDogCompanion: View {
    let tailAngle: Double
    let blink: Bool
    let headTilt: Double
    let hopOffset: CGFloat
    let facingLeft: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            DogTailShape()
                .stroke(
                    NotchColors.textPrimary,
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round)
                )
                .frame(width: 30, height: 15)
                .rotationEffect(.degrees(tailAngle), anchor: UnitPoint(x: 0.25, y: 0.68))

            DogBodyShape()
                .fill(NotchColors.textPrimary)
                .frame(width: 30, height: 15)

            // Dark separator defining the floppy ear against the white puppy silhouette
            DogEarOutlineShape()
                .stroke(
                    Color.black,
                    style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 30, height: 15)

            // Eye and nose accents
            Circle()
                .fill(Color.black)
                .frame(width: 1.8, height: 1.8)
                .scaleEffect(y: blink ? 0.2 : 1.0, anchor: .center)
                .offset(x: 19.0, y: 4.1)

            Circle()
                .fill(Color.black)
                .frame(width: 1.9, height: 1.9)
                .offset(x: 24.4, y: 5.1)
        }
        .frame(width: 30, height: 15)
        .rotationEffect(.degrees(headTilt), anchor: .bottom)
        .scaleEffect(x: facingLeft ? -1 : 1, y: 1, anchor: .center)
        .offset(y: hopOffset)
    }
}

private struct DogBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 30
        let sy = rect.height / 15
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

        var path = Path()
        // Side-profile sitting puppy facing right with snout and chest
        path.move(to: p(7.4, 14.0))
        path.addQuadCurve(to: p(8.8, 8.6), control: p(6.8, 10.8))
        path.addQuadCurve(to: p(14.0, 7.6), control: p(11.2, 7.6))
        path.addQuadCurve(to: p(14.8, 2.2), control: p(13.4, 4.4))
        path.addQuadCurve(to: p(21.0, 3.0), control: p(18.2, 1.2))
        path.addLine(to: p(25.4, 4.4))
        path.addQuadCurve(to: p(25.8, 7.2), control: p(26.8, 5.6))
        path.addLine(to: p(22.0, 7.8))
        path.addLine(to: p(20.9, 14.0))
        path.closeSubpath()
        return path
    }
}

private struct DogTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 30
        let sy = rect.height / 15
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

        var path = Path()
        path.move(to: p(7.6, 10.4))
        path.addQuadCurve(to: p(4.2, 5.2), control: p(4.9, 8.6))
        return path
    }
}

private struct DogEarOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 30
        let sy = rect.height / 15
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

        var path = Path()
        path.move(to: p(16.2, 3.3))
        path.addQuadCurve(to: p(14.3, 7.7), control: p(14.0, 5.6))
        path.addQuadCurve(to: p(17.7, 6.4), control: p(16.8, 8.2))
        return path
    }
}

private struct DualAcousticWaveCanvas: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = size.width

            func wavePath(amplitude: CGFloat, frequency: Double, phaseShift: Double) -> Path {
                var path = Path()
                let steps = 28
                for step in 0...steps {
                    let t = Double(step) / Double(steps)
                    let x = t * width
                    // Smooth taper envelope so ends melt cleanly toward the baseline
                    let envelope = sin(t * .pi)
                    let y = midY + sin(t * frequency * .pi * 2 + phase + phaseShift) * amplitude * envelope
                    if step == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                return path
            }

            context.stroke(
                wavePath(amplitude: 4.0, frequency: 1.8, phaseShift: 0),
                with: .color(NotchColors.textPrimary),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                wavePath(amplitude: 3.1, frequency: 2.3, phaseShift: 1.4),
                with: .color(Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255)),
                style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
