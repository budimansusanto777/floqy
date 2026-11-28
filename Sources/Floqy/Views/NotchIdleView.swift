import AppKit
import QuartzCore
import SwiftUI

/// Idle notch mini-chin rendering the selected companion and reacting to global pointer motion.
struct NotchIdleView: View {
    @ObservedObject var manager: NotchManager
    @ObservedObject var productivity: ProductivityService
    @ObservedObject var hardware: HardwareStatusService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isDisplayAsleep) private var isDisplayAsleep

    @StateObject private var pointerTracker = IdlePointerTracker()
    @StateObject private var petDriver = PetWalkDriver()
    @State private var isBlinking = false
    @State private var isHappyMood = false
    @State private var gazeOffset: CGSize = .zero
    @State private var eyeCuriosity: CGFloat = 0
    @State private var petBlink = false
    @State private var isPointerActive = false
    @State private var horizonExpanded = false
    @State private var pointerSettleTask: Task<Void, Never>?

    private var tracksPointerMotion: Bool {
        guard !reduceMotion, !isDisplayAsleep else { return false }
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
                let totalWidth = cameraWidth + NotchGeometry.sideWingSlotWidth * 2
                let height = manager.geometry.hasHardwareNotch
                    ? manager.geometry.hardwareNotchSize.height
                    : 34
                petTunnelStage(totalWidth: totalWidth, cameraWidth: cameraWidth, height: height)
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
        .task(id: "\(manager.idleAppearance.rawValue)-\(reduceMotion)-\(isDisplayAsleep)") {
            await runIdleAnimationLoop()
        }
        .task(id: manager.idleHappyUntil) {
            await updateHappyWindow()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onAppear {
            syncPetBounds()
            configurePointerTracking()
        }
        .onChange(of: manager.idleAppearance) { _, _ in
            syncPetBounds()
            configurePointerTracking()
        }
        .onChange(of: manager.geometry) { _, _ in
            syncPetBounds()
        }
        .onChange(of: reduceMotion) { _, _ in
            syncPetBounds()
            configurePointerTracking()
        }
        .onChange(of: isDisplayAsleep) { _, asleep in
            if asleep {
                petDriver.stop(snapToRest: true)
            }
            configurePointerTracking()
        }
        .onDisappear {
            pointerTracker.setActive(false)
            petDriver.stop()
            pointerSettleTask?.cancel()
            pointerSettleTask = nil
            isPointerActive = false
            gazeOffset = .zero
            eyeCuriosity = 0
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
        case .off, .cat, .dog:
            Color.clear
        case .eyes:
            eyesContent
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
                expressiveEyeCapsule(side: -1)
                expressiveEyeCapsule(side: 1)
            }
        }
        .offset(reduceMotion ? .zero : gazeOffset)
    }

    private func expressiveEyeCapsule(side: CGFloat) -> some View {
        let normalizedX = reduceMotion ? 0 : max(-1, min(1, gazeOffset.width / 3.0))
        let depthScale = max(0.86, min(1.10, 1 - side * normalizedX * 0.12))
        let curiousScale = reduceMotion ? 1.0 : (1 + eyeCuriosity * 0.16)
        let width = 6.5 * depthScale * (1 + (reduceMotion ? 0 : eyeCuriosity * 0.06))
        let height = 10.5 * curiousScale

        return Capsule(style: .continuous)
            .fill(NotchColors.textPrimary)
            .frame(width: width, height: height)
            .scaleEffect(
                x: (isBlinking && !reduceMotion) ? 1.08 : 1.0,
                y: (isBlinking && !reduceMotion) ? 0.12 : 1.0,
                anchor: .center
            )
    }

    private var sleepyEyeCapsule: some View {
        Capsule(style: .continuous)
            .fill(NotchColors.textPrimary.opacity(0.82))
            .frame(width: 6.8, height: 3.6)
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
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPointerActive || isDisplayAsleep)) { context in
                    DualAcousticWaveCanvas(phase: context.date.timeIntervalSinceReferenceDate * 6.2)
                        .frame(width: 46, height: 12)
                }
                .opacity(isPointerActive ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPointerActive)
    }

    private func petTunnelStage(totalWidth: CGFloat, cameraWidth: CGFloat, height: CGFloat) -> some View {
        let isDog = manager.idleAppearance == .dog
        let petWidth: CGFloat = isDog ? 34 : 32
        let isSitting = reduceMotion ? true : petDriver.isSitting
        let facing: CGFloat = reduceMotion ? 1 : petDriver.facingScaleX

        return ZStack(alignment: .bottomLeading) {
            ZStack {
                if isDog {
                    FloqyPoodleMascotView(
                        mode: .idle,
                        width: petWidth,
                        gazeOffset: reduceMotion ? .zero : gazeOffset,
                        isBlinking: !reduceMotion && petBlink,
                        isHappy: isHappyMood,
                        showSparks: isHappyMood,
                        isCelebrating: isHappyMood
                    )
                    .opacity(isSitting ? 1 : 0)
                    .offset(y: isSitting ? 0 : 2)

                    FloqyPoodleMascotView(
                        mode: .walking(phase: petDriver.walkPhase, strideFactor: petDriver.strideFactor),
                        width: petWidth
                    )
                    .scaleEffect(x: facing, y: 1, anchor: .center)
                    .opacity(isSitting ? 0 : 1)
                    .offset(y: isSitting ? 2 : 0)
                } else {
                    FloqyCalicoMascotView(
                        mode: .sitting,
                        width: petWidth,
                        isBlinking: !reduceMotion && petBlink,
                        isHappy: isHappyMood,
                        showSparks: isHappyMood,
                        isCelebrating: isHappyMood
                    )
                    .opacity(isSitting ? 1 : 0)
                    .offset(y: isSitting ? 0 : 2)

                    FloqyCalicoMascotView(
                        mode: .walking(phase: petDriver.walkPhase, strideFactor: petDriver.strideFactor),
                        width: petWidth
                    )
                    .opacity(isSitting ? 0 : 1)
                    .offset(y: isSitting ? 2 : 0)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: isDog ? 0.24 : 0.20), value: isSitting)
            .scaleEffect(x: isDog ? 1 : facing, y: 1, anchor: .center)
            .offset(x: petDriver.x, y: isDog ? -1 : -2)

            // Occlude the center camera region so pets walk cleanly behind the physical bezel.
            Color.black
                .frame(width: cameraWidth, height: height)
                .frame(width: totalWidth, height: height, alignment: .center)
                .allowsHitTesting(false)
        }
        .frame(width: totalWidth, height: height, alignment: .bottomLeading)
        .clipped()
    }

    private func syncPetBounds() {
        let cameraWidth = manager.geometry.hasHardwareNotch
            ? manager.geometry.hardwareNotchSize.width
            : 196
        let totalWidth = cameraWidth + NotchGeometry.sideWingSlotWidth * 2
        let petWidth: CGFloat = manager.idleAppearance == .dog ? 34 : 32
        petDriver.configureProfile(for: manager.idleAppearance)
        petDriver.configureBounds(totalWidth: totalWidth, cameraWidth: cameraWidth, petWidth: petWidth)
        if !manager.idleAppearance.isSideWing || reduceMotion {
            petDriver.stop(snapToRest: reduceMotion)
        }
    }

    private func resetPetStates() {
        petBlink = false
    }

    private func configurePointerTracking() {
        pointerSettleTask?.cancel()
        pointerSettleTask = nil
        isPointerActive = false
        gazeOffset = .zero
        eyeCuriosity = 0
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
            let dx = max(-3.0, min(3.0, ((screenPoint.x - screen.midX) / halfW) * 3.0))
            let dy = max(-0.5, min(1.8, ((screen.maxY - screenPoint.y) / height) * 1.8))
            let normDist = hypot(
                (screenPoint.x - screen.midX) / max(1, screen.width * 0.35),
                (screen.maxY - screenPoint.y) / max(1, screen.height * 0.35)
            )
            let proximity = max(0, min(1, 1 - normDist))
            withAnimation(.easeOut(duration: 0.14)) {
                gazeOffset = CGSize(width: dx, height: dy)
                eyeCuriosity = proximity
            }
            pointerSettleTask?.cancel()
            pointerSettleTask = Task {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    gazeOffset = .zero
                    eyeCuriosity = 0
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
            let normalizedX = max(0, min(1, (screenPoint.x - screen.minX) / max(1, screen.width)))
            petDriver.updateTarget(normalizedScreenX: normalizedX)

        case .dog:
            let normalizedX = max(0, min(1, (screenPoint.x - screen.minX) / max(1, screen.width)))
            petDriver.updateTarget(normalizedScreenX: normalizedX)

            let height = max(1, screen.height)
            let dx = max(-2.1, min(2.1, ((screenPoint.x - screen.midX) / halfW) * 2.1))
            let dy = max(-1.0, min(1.6, ((screen.maxY - screenPoint.y) / height) * 1.4))
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

    private func performEyeBlink(closeSec: Double, holdMs: Int, openSec: Double) async {
        withAnimation(.easeIn(duration: closeSec)) {
            isBlinking = true
        }
        try? await Task.sleep(for: .milliseconds(holdMs))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: openSec)) {
            isBlinking = false
        }
    }

    private func runIdleAnimationLoop() async {
        isBlinking = false
        resetPetStates()
        horizonExpanded = false

        guard !reduceMotion, !isDisplayAsleep else { return }

        switch manager.idleAppearance {
        case .off, .wave:
            return
        case .eyes:
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.6...5.0)))
                guard !Task.isCancelled else { break }
                await performEyeBlink(closeSec: 0.08, holdMs: 100, openSec: 0.11)
                guard !Task.isCancelled else { break }
                if Double.random(in: 0...1) < 0.22 {
                    try? await Task.sleep(for: .milliseconds(95))
                    guard !Task.isCancelled else { break }
                    await performEyeBlink(closeSec: 0.07, holdMs: 85, openSec: 0.10)
                }
            }
        case .cat:
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.2))
                guard !Task.isCancelled else { break }
                if petDriver.isSitting {
                    await performPetBlink(durationMs: 120)
                }
            }
        case .dog:
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.3))
                guard !Task.isCancelled else { break }
                if petDriver.isSitting {
                    await performPetBlink(durationMs: 120)
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

/// Drives smooth inertial walking behind the camera cutout and settles into resting pose when the mouse settles.
@MainActor
private final class PetWalkDriver: ObservableObject {
    @Published private(set) var x: CGFloat = 0
    @Published private(set) var walkPhase: CGFloat = 0
    @Published private(set) var strideFactor: CGFloat = 0
    @Published private(set) var facingScaleX: CGFloat = 1
    @Published private(set) var isSitting: Bool = true

    private var timer: Timer?
    private var hasConfigured = false
    private var leftRange: ClosedRange<CGFloat> = 15...21
    private var rightRange: ClosedRange<CGFloat> = 259...265
    private var tunnelSpan: ClosedRange<CGFloat> = 52...228
    private var targetWingIsLeft = false
    private var targetX: CGFloat = 262
    private var vx: CGFloat = 0
    private var facingLeft = false
    private var stillTime: TimeInterval = 0
    private var lastStepTime: CFTimeInterval = 0
    private var wingMaxSpeed: CGFloat = 48
    private var tunnelMaxSpeed: CGFloat = 220
    private var wingGain: CGFloat = 2.5
    private var tunnelGain: CGFloat = 4.2
    private var phaseRate: CGFloat = 0.28

    deinit {
        timer?.invalidate()
    }

    func configureProfile(for appearance: IdleAppearance) {
        if appearance == .dog {
            wingMaxSpeed = 34
            tunnelMaxSpeed = 155
            wingGain = 2.0
            tunnelGain = 3.2
            phaseRate = 0.22
        } else {
            wingMaxSpeed = 48
            tunnelMaxSpeed = 220
            wingGain = 2.5
            tunnelGain = 4.2
            phaseRate = 0.28
        }
    }

    func configureBounds(totalWidth: CGFloat, cameraWidth: CGFloat, petWidth: CGFloat) {
        let ear = NotchGeometry.earWidth
        let wing = NotchGeometry.sideWingWidth
        let leftMin = ear + 3
        let leftMax = max(leftMin, ear + wing - petWidth - 3)
        let rightMin = totalWidth - ear - wing + 3
        let rightMax = max(rightMin, totalWidth - ear - petWidth - 3)
        let tStart = ear + wing - 4
        let tEnd = max(tStart, totalWidth - ear - wing - petWidth + 4)

        leftRange = leftMin...leftMax
        rightRange = rightMin...rightMax
        tunnelSpan = tStart...tEnd

        let restingRight = (rightMin + rightMax) / 2
        if !hasConfigured {
            hasConfigured = true
            x = restingRight
            targetX = restingRight
            targetWingIsLeft = false
            facingScaleX = 1
        } else {
            x = targetWingIsLeft ? min(max(x, leftMin), leftMax) : min(max(x, rightMin), rightMax)
            targetX = targetWingIsLeft ? (leftMin + leftMax) / 2 : restingRight
        }
        _ = cameraWidth
    }

    func updateTarget(normalizedScreenX: CGFloat) {
        if normalizedScreenX < 0.45 {
            targetWingIsLeft = true
            let t = normalizedScreenX / 0.45
            targetX = leftRange.lowerBound + t * (leftRange.upperBound - leftRange.lowerBound)
        } else if normalizedScreenX > 0.55 {
            targetWingIsLeft = false
            let t = (normalizedScreenX - 0.55) / 0.45
            targetX = rightRange.lowerBound + t * (rightRange.upperBound - rightRange.lowerBound)
        }

        let diff = targetX - x
        if isSitting && abs(diff) > 6 {
            isSitting = false
            stillTime = 0
            startTimerIfNeeded()
        }
    }

    func stop(snapToRest: Bool = false) {
        timer?.invalidate()
        timer = nil
        vx = 0
        strideFactor = 0
        stillTime = 0
        if snapToRest {
            isSitting = true
            x = targetWingIsLeft ? (leftRange.lowerBound + leftRange.upperBound) / 2 : (rightRange.lowerBound + rightRange.upperBound) / 2
            facingScaleX = targetWingIsLeft ? -1 : 1
        }
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        lastStepTime = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.step()
            }
        }
    }

    private func step() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(min(0.05, max(0.001, now - lastStepTime)))
        lastStepTime = now

        let diff = targetX - x
        let inTunnel = x > tunnelSpan.lowerBound && x < tunnelSpan.upperBound
        let maxSpeed: CGFloat = inTunnel ? tunnelMaxSpeed : wingMaxSpeed
        let gain: CGFloat = inTunnel ? tunnelGain : wingGain

        let desiredVx: CGFloat = abs(diff) > 1.2
            ? max(-maxSpeed, min(maxSpeed, diff * gain))
            : 0
        vx += (desiredVx - vx) * min(1, dt * 8.5)
        x += vx * dt

        walkPhase += abs(vx) * dt * phaseRate
        strideFactor = min(1, abs(vx) / 20)

        if abs(diff) > 3.0 {
            facingLeft = diff < 0
        }
        let desiredScale: CGFloat = facingLeft ? -1 : 1
        facingScaleX += (desiredScale - facingScaleX) * min(1, dt * 14)

        if !inTunnel && abs(diff) <= 2.2 && abs(vx) < 4.5 {
            stillTime += TimeInterval(dt)
            if stillTime >= 0.50 {
                vx = 0
                strideFactor = 0
                stillTime = 0
                facingScaleX = targetWingIsLeft ? -1 : 1
                isSitting = true
                timer?.invalidate()
                timer = nil
            }
        } else {
            stillTime = 0
        }
    }
}

enum CalicoMascotMode: Equatable {
    case sitting
    case walking(phase: CGFloat, strideFactor: CGFloat)
    case working
    case done
}

/// Colored Calico Cat vector mascot across sitting loaf, camera-tunnel walk, brisk Working, and Done celebration.
struct FloqyCalicoMascotView: View {
    let mode: CalicoMascotMode
    let width: CGFloat
    var isBlinking: Bool = false
    var isHappy: Bool = false
    var showSparks: Bool = false
    var isCelebrating: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isDisplayAsleep) private var isDisplayAsleep

    var body: some View {
        let height = round(width * 0.72)
        let animateLoop = mode == .working && !reduceMotion && !isDisplayAsleep
        let hopY: CGFloat = (mode == .done && !reduceMotion && !isCelebrating) ? 4 : 0
        let hopScale: CGFloat = (mode == .done && !reduceMotion && !isCelebrating) ? 0.9 : 1.0

        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !animateLoop)) { context in
            let t = animateLoop ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, canvasSize in
                drawCalico(in: &ctx, size: canvasSize, time: t)
            }
        }
        .frame(width: width, height: height)
        .scaleEffect(hopScale, anchor: .bottom)
        .offset(y: hopY)
        .accessibilityHidden(true)
    }

    private func drawCalico(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let sx = size.width / 64.0
        let sy = size.height / 46.0

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        func fillRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, angleDeg: CGFloat, anchor: CGPoint, color: Color) {
            var local = context
            local.translateBy(x: anchor.x * sx, y: anchor.y * sy)
            local.rotate(by: .degrees(angleDeg))
            local.translateBy(x: -anchor.x * sx, y: -anchor.y * sy)
            let rect = CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)
            local.fill(Path(roundedRect: rect, cornerRadius: (w / 2) * sx), with: .color(color))
        }

        let cream = Color(red: 255 / 255, green: 245 / 255, blue: 232 / 255)
        let creamShadow = Color(red: 216 / 255, green: 198 / 255, blue: 176 / 255)
        let orange = Color(red: 238 / 255, green: 134 / 255, blue: 54 / 255)
        let orangeDeep = Color(red: 201 / 255, green: 105 / 255, blue: 32 / 255)
        let cocoa = Color(red: 59 / 255, green: 40 / 255, blue: 30 / 255)
        let earPink = Color(red: 244 / 255, green: 153 / 255, blue: 175 / 255)
        let nosePink = Color(red: 240 / 255, green: 124 / 255, blue: 149 / 255)
        let inkDark = Color(red: 38 / 255, green: 20 / 255, blue: 9 / 255)

        if showSparks {
            drawSparks(in: &context, sx: sx, sy: sy, isWorking: mode == .working && !reduceMotion, time: time)
        }

        switch mode {
        case .walking(let phase, let strideFactor):
            let swingA = CGFloat(sin(phase)) * 22 * strideFactor
            let swingB = CGFloat(sin(phase + .pi)) * 22 * strideFactor
            let bounceY: CGFloat = CGFloat(-abs(sin(phase))) * 1.15 * strideFactor
            let tailDeg = CGFloat(sin(phase * 1.05 + 0.6)) * 9 * (0.35 + 0.65 * strideFactor)

            var tail = Path()
            tail.move(to: pt(15, 25 + bounceY))
            tail.addCurve(to: pt(11, 9 + bounceY), control1: pt(8, 22 + bounceY), control2: pt(6, 12 + bounceY))
            var tailCtx = context
            tailCtx.translateBy(x: 15 * sx, y: (25 + bounceY) * sy)
            tailCtx.rotate(by: .degrees(tailDeg))
            tailCtx.translateBy(x: -15 * sx, y: -(25 + bounceY) * sy)
            tailCtx.stroke(tail, with: .color(orange), style: StrokeStyle(lineWidth: 4.2 * sx, lineCap: .round))
            tailCtx.fill(Path(ellipseIn: CGRect(x: 9.0 * sx, y: (6.8 + bounceY) * sy, width: 4.4 * sx, height: 4.4 * sy)), with: .color(cocoa))

            // Far legs
            fillRect(18, 31 + bounceY, 4.4, 12, angleDeg: swingB, anchor: CGPoint(x: 20, y: 31 + bounceY), color: creamShadow)
            fillRect(38, 31 + bounceY, 4.4, 12, angleDeg: swingA, anchor: CGPoint(x: 40, y: 31 + bounceY), color: orangeDeep)

            // Torso + patches
            context.fill(Path(ellipseIn: CGRect(x: 14.5 * sx, y: (19.7 + bounceY) * sy, width: 29 * sx, height: 15.6 * sy)), with: .color(cream))
            var rump = Path()
            rump.move(to: pt(16, 24.5 + bounceY))
            rump.addCurve(to: pt(29.5, 25.5 + bounceY), control1: pt(20, 19.8 + bounceY), control2: pt(27, 20.5 + bounceY))
            rump.addCurve(to: pt(16, 24.5 + bounceY), control1: pt(25, 27.5 + bounceY), control2: pt(20, 27.5 + bounceY))
            context.fill(rump, with: .color(cocoa))

            var shoulder = Path()
            shoulder.move(to: pt(27.5, 21.0 + bounceY))
            shoulder.addCurve(to: pt(41.0, 27.0 + bounceY), control1: pt(33.5, 19.8 + bounceY), control2: pt(39.5, 22.0 + bounceY))
            shoulder.addCurve(to: pt(27.5, 21.0 + bounceY), control1: pt(36.5, 28.5 + bounceY), control2: pt(31.5, 27.5 + bounceY))
            context.fill(shoulder, with: .color(orange))

            // Near legs
            fillRect(21, 31.5 + bounceY, 4.8, 12, angleDeg: swingA, anchor: CGPoint(x: 23, y: 31.5 + bounceY), color: cocoa)
            fillRect(35, 31.5 + bounceY, 4.8, 12, angleDeg: swingB, anchor: CGPoint(x: 37, y: 31.5 + bounceY), color: cream)

            // Ears + forward head
            var lEar = Path()
            lEar.move(to: pt(35, 14 + bounceY))
            lEar.addLine(to: pt(34.5, 4 + bounceY))
            lEar.addLine(to: pt(42, 10 + bounceY))
            lEar.closeSubpath()
            context.fill(lEar, with: .color(cocoa))

            var rEar = Path()
            rEar.move(to: pt(46, 14 + bounceY))
            rEar.addLine(to: pt(49.5, 3.6 + bounceY))
            rEar.addLine(to: pt(52, 13 + bounceY))
            rEar.closeSubpath()
            context.fill(rEar, with: .color(orange))

            var rEarIn = Path()
            rEarIn.move(to: pt(47.2, 12.6 + bounceY))
            rEarIn.addLine(to: pt(49.0, 6.2 + bounceY))
            rEarIn.addLine(to: pt(50.8, 11.8 + bounceY))
            rEarIn.closeSubpath()
            context.fill(rEarIn, with: .color(earPink))

            context.fill(Path(ellipseIn: CGRect(x: 32.5 * sx, y: (8.4 + bounceY) * sy, width: 23 * sx, height: 19.6 * sy)), with: .color(cream))
            var lPatch = Path()
            lPatch.move(to: pt(34.5, 15.0 + bounceY))
            lPatch.addCurve(to: pt(44.5, 13.5 + bounceY), control1: pt(36.2, 9.5 + bounceY), control2: pt(42.0, 9.0 + bounceY))
            lPatch.addCurve(to: pt(34.5, 15.0 + bounceY), control1: pt(41.5, 16.0 + bounceY), control2: pt(37.5, 16.2 + bounceY))
            context.fill(lPatch, with: .color(cocoa))

            var rPatch = Path()
            rPatch.move(to: pt(45.2, 13.0 + bounceY))
            rPatch.addCurve(to: pt(54.2, 15.8 + bounceY), control1: pt(48.2, 9.2 + bounceY), control2: pt(53.5, 11.2 + bounceY))
            rPatch.addCurve(to: pt(45.2, 13.0 + bounceY), control1: pt(51.0, 16.5 + bounceY), control2: pt(47.5, 15.8 + bounceY))
            context.fill(rPatch, with: .color(orange))

            context.fill(Path(ellipseIn: CGRect(x: 46.3 * sx, y: (15.6 + bounceY) * sy, width: 4.4 * sx, height: 4.4 * sy)), with: .color(inkDark))
            context.fill(Path(ellipseIn: CGRect(x: 47.1 * sx, y: (16.2 + bounceY) * sy, width: 1.6 * sx, height: 1.6 * sy)), with: .color(.white))

            var nose = Path()
            nose.move(to: pt(52.8, 19.6 + bounceY))
            nose.addLine(to: pt(55.6, 19.6 + bounceY))
            nose.addLine(to: pt(54.4, 21.2 + bounceY))
            nose.closeSubpath()
            context.fill(nose, with: .color(nosePink))

        case .sitting, .working:
            let isWorking = mode == .working && !reduceMotion
            let tailDeg: CGFloat = isWorking ? CGFloat(sin(time * 12.0)) * 14 : 0

            // Loaf body + orange/cocoa back patches
            context.fill(Path(ellipseIn: CGRect(x: 22 * sx, y: 25 * sy, width: 32 * sx, height: 19 * sy)), with: .color(cream))
            var backOrange = Path()
            backOrange.move(to: pt(30, 26.2))
            backOrange.addCurve(to: pt(44.5, 33.5), control1: pt(36, 24.5), control2: pt(43, 26.5))
            backOrange.addCurve(to: pt(30, 26.2), control1: pt(39, 34.5), control2: pt(34, 33))
            context.fill(backOrange, with: .color(orange))

            var backCocoa = Path()
            backCocoa.move(to: pt(41.5, 27.2))
            backCocoa.addCurve(to: pt(52, 38.5), control1: pt(48.5, 28), control2: pt(53.5, 33))
            backCocoa.addCurve(to: pt(41.5, 27.2), control1: pt(46, 39), control2: pt(42, 35.5))
            context.fill(backCocoa, with: .color(cocoa))

            // Tail
            var tail = Path()
            tail.move(to: pt(52, 38.5))
            tail.addCurve(to: pt(56.5, 26.5), control1: pt(58.5, 38.5), control2: pt(60, 31.5))
            var tailCtx = context
            tailCtx.translateBy(x: 50 * sx, y: 38 * sy)
            tailCtx.rotate(by: .degrees(tailDeg))
            tailCtx.translateBy(x: -50 * sx, y: -38 * sy)
            tailCtx.stroke(tail, with: .color(orange), style: StrokeStyle(lineWidth: 4.2 * sx, lineCap: .round))
            tailCtx.fill(Path(ellipseIn: CGRect(x: 54.2 * sx, y: 24.0 * sy, width: 4.4 * sx, height: 4.4 * sy)), with: .color(cocoa))

            // Ears
            var lEar = Path()
            lEar.move(to: pt(11.5, 19.5))
            lEar.addLine(to: pt(10.6, 6.6))
            lEar.addLine(to: pt(20.5, 14.0))
            lEar.closeSubpath()
            context.fill(lEar, with: .color(orange))

            var rEar = Path()
            rEar.move(to: pt(36.5, 19.5))
            rEar.addLine(to: pt(37.6, 6.6))
            rEar.addLine(to: pt(27.5, 14.0))
            rEar.closeSubpath()
            context.fill(rEar, with: .color(cocoa))

            for earPts in [
                (CGPoint(x: 12.6, y: 17.4), CGPoint(x: 11.9, y: 9.6), CGPoint(x: 18.4, y: 14.6)),
                (CGPoint(x: 35.4, y: 17.4), CGPoint(x: 36.2, y: 9.6), CGPoint(x: 29.6, y: 14.6))
            ] {
                var p = Path()
                p.move(to: pt(earPts.0.x, earPts.0.y))
                p.addLine(to: pt(earPts.1.x, earPts.1.y))
                p.addLine(to: pt(earPts.2.x, earPts.2.y))
                p.closeSubpath()
                context.fill(p, with: .color(earPink.opacity(0.88)))
            }

            // Head + patches
            context.fill(Path(ellipseIn: CGRect(x: 9.8 * sx, y: 13.2 * sy, width: 28.4 * sx, height: 23.2 * sy)), with: .color(cream))
            var fhOrange = Path()
            fhOrange.move(to: pt(11.2, 21.5))
            fhOrange.addCurve(to: pt(23.0, 18.8), control1: pt(12.5, 14.2), control2: pt(19.5, 13.0))
            fhOrange.addCurve(to: pt(11.2, 21.5), control1: pt(19.5, 21.5), control2: pt(14.5, 22.0))
            context.fill(fhOrange, with: .color(orange))

            var fhCocoa = Path()
            fhCocoa.move(to: pt(36.8, 21.5))
            fhCocoa.addCurve(to: pt(25.2, 18.5), control1: pt(35.5, 14.2), control2: pt(28.5, 13.0))
            fhCocoa.addCurve(to: pt(36.8, 21.5), control1: pt(28.5, 21.2), control2: pt(33.5, 22.0))
            context.fill(fhCocoa, with: .color(cocoa))

            // Nose + smile
            var nose = Path()
            nose.move(to: pt(22.4, 26.8))
            nose.addLine(to: pt(25.6, 26.8))
            nose.addLine(to: pt(24.0, 28.4))
            nose.closeSubpath()
            context.fill(nose, with: .color(nosePink))

            var mouth = Path()
            mouth.move(to: pt(21.6, 29.3))
            mouth.addQuadCurve(to: pt(24.0, 29.2), control: pt(22.8, 30.5))
            mouth.addQuadCurve(to: pt(26.4, 29.3), control: pt(25.2, 30.5))
            context.stroke(mouth, with: .color(cocoa), style: StrokeStyle(lineWidth: max(0.8, 1.15 * sx), lineCap: .round))

            if isHappy {
                for cx in [CGFloat(17.8), CGFloat(30.2)] {
                    var arc = Path()
                    arc.move(to: pt(cx - 2.6, 25.0))
                    arc.addQuadCurve(to: pt(cx + 2.6, 25.0), control: pt(cx, 21.8))
                    context.stroke(arc, with: .color(inkDark), style: StrokeStyle(lineWidth: max(1.2, 2.2 * sx), lineCap: .round))
                }
            } else {
                let scaleY: CGFloat = isBlinking ? 0.14 : 1.0
                for cx in [CGFloat(17.8), CGFloat(30.2)] {
                    context.fill(Path(ellipseIn: CGRect(x: (cx - 2.4) * sx, y: (24.4 - 2.4 * scaleY) * sy, width: 4.8 * sx, height: 4.8 * scaleY * sy)), with: .color(inkDark))
                    if !isBlinking {
                        context.fill(Path(ellipseIn: CGRect(x: (cx - 1.55) * sx, y: 22.65 * sy, width: 1.7 * sx, height: 1.7 * sy)), with: .color(.white))
                    }
                }
            }

            // Tucked paws
            context.fill(Path(ellipseIn: CGRect(x: 12.3 * sx, y: 37.6 * sy, width: 10.4 * sx, height: 6.4 * sy)), with: .color(cream))
            context.fill(Path(ellipseIn: CGRect(x: 25.3 * sx, y: 37.6 * sy, width: 10.4 * sx, height: 6.4 * sy)), with: .color(orange))

        case .done:
            // Front-facing peeking Calico celebration pose matching the Poodle Done alert
            var lEar = Path()
            lEar.move(to: pt(15.2, 21.8))
            lEar.addLine(to: pt(13.2, 6.2))
            lEar.addLine(to: pt(25.8, 14.2))
            lEar.closeSubpath()
            context.fill(lEar, with: .color(orange))

            var rEar = Path()
            rEar.move(to: pt(48.8, 21.8))
            rEar.addLine(to: pt(50.8, 6.2))
            rEar.addLine(to: pt(38.2, 14.2))
            rEar.closeSubpath()
            context.fill(rEar, with: .color(cocoa))

            for earPts in [
                (CGPoint(x: 16.5, y: 19.2), CGPoint(x: 15.2, y: 9.6), CGPoint(x: 23.2, y: 15.0)),
                (CGPoint(x: 47.5, y: 19.2), CGPoint(x: 48.8, y: 9.6), CGPoint(x: 40.8, y: 15.0))
            ] {
                var p = Path()
                p.move(to: pt(earPts.0.x, earPts.0.y))
                p.addLine(to: pt(earPts.1.x, earPts.1.y))
                p.addLine(to: pt(earPts.2.x, earPts.2.y))
                p.closeSubpath()
                context.fill(p, with: .color(earPink.opacity(0.9)))
            }

            context.fill(Path(ellipseIn: CGRect(x: 14.2 * sx, y: 13.4 * sy, width: 35.6 * sx, height: 27.6 * sy)), with: .color(cream))

            var leftFh = Path()
            leftFh.move(to: pt(14.8, 23.8))
            leftFh.addCurve(to: pt(30.8, 19.6), control1: pt(16.8, 14.5), control2: pt(26.2, 13.0))
            leftFh.addCurve(to: pt(14.8, 23.8), control1: pt(26.2, 22.8), control2: pt(19.4, 23.8))
            context.fill(leftFh, with: .color(orange))

            var rightFh = Path()
            rightFh.move(to: pt(49.2, 23.8))
            rightFh.addCurve(to: pt(33.2, 19.6), control1: pt(47.2, 14.5), control2: pt(37.8, 13.0))
            rightFh.addCurve(to: pt(49.2, 23.8), control1: pt(37.8, 22.8), control2: pt(44.6, 23.8))
            context.fill(rightFh, with: .color(cocoa))

            // Rosy cheeks
            let blush = Color(red: 244 / 255, green: 139 / 255, blue: 139 / 255).opacity(0.48)
            context.fill(Path(ellipseIn: CGRect(x: 15.3 * sx, y: 29.4 * sy, width: 5.8 * sx, height: 3.2 * sy)), with: .color(blush))
            context.fill(Path(ellipseIn: CGRect(x: 42.9 * sx, y: 29.4 * sy, width: 5.8 * sx, height: 3.2 * sy)), with: .color(blush))

            // Happy curved eyes (^ ^), pink nose & smile
            for cx in [CGFloat(23.5), CGFloat(40.5)] {
                var arc = Path()
                arc.move(to: pt(cx - 3.0, 28.0))
                arc.addQuadCurve(to: pt(cx + 3.0, 28.0), control: pt(cx, 24.2))
                context.stroke(arc, with: .color(inkDark), style: StrokeStyle(lineWidth: max(1.4, 2.4 * sx), lineCap: .round))
            }

            var nose = Path()
            nose.move(to: pt(29.8, 29.6))
            nose.addLine(to: pt(34.2, 29.6))
            nose.addLine(to: pt(32.0, 31.6))
            nose.closeSubpath()
            context.fill(nose, with: .color(nosePink))

            var mouth = Path()
            mouth.move(to: pt(28.8, 32.8))
            mouth.addQuadCurve(to: pt(32.0, 32.6), control: pt(30.4, 34.2))
            mouth.addQuadCurve(to: pt(35.2, 32.8), control: pt(33.6, 34.2))
            context.stroke(mouth, with: .color(cocoa), style: StrokeStyle(lineWidth: max(0.9, 1.2 * sx), lineCap: .round))

            // Raised happy rounded paws
            let pawY: CGFloat = reduceMotion ? 0 : -3.2
            context.fill(Path(ellipseIn: CGRect(x: 9.9 * sx, y: (36.4 + pawY) * sy, width: 13.2 * sx, height: 8.4 * sy)), with: .color(cream))
            context.fill(Path(ellipseIn: CGRect(x: 12.1 * sx, y: (37.4 + pawY) * sy, width: 8.8 * sx, height: 5.2 * sy)), with: .color(earPink.opacity(0.55)))
            context.fill(Path(ellipseIn: CGRect(x: 40.9 * sx, y: (36.4 + pawY) * sy, width: 13.2 * sx, height: 8.4 * sy)), with: .color(orange))
            context.fill(Path(ellipseIn: CGRect(x: 43.1 * sx, y: (37.4 + pawY) * sy, width: 8.8 * sx, height: 5.2 * sy)), with: .color(cream.opacity(0.85)))
        }
    }

    private func drawSparks(
        in context: inout GraphicsContext,
        sx: CGFloat,
        sy: CGFloat,
        isWorking: Bool,
        time: TimeInterval
    ) {
        let sparkColor = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
        let alphaA = isWorking ? (0.35 + 0.65 * ((sin(time * 6.0) + 1.0) * 0.5)) : ((mode == .done && !isCelebrating && !reduceMotion) ? 0.0 : 0.98)
        let alphaB = isWorking ? (0.35 + 0.65 * ((sin(time * 6.0 + .pi) + 1.0) * 0.5)) : ((mode == .done && !isCelebrating && !reduceMotion) ? 0.0 : 0.98)

        let specs: [(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, angleDeg: CGFloat, alpha: Double)] = [
            (49.7, 8.2, 5.2, 11.2, 22, alphaA),
            (57.0, 13.7, 4.8, 10.2, 42, alphaB)
        ]
        for spec in specs {
            var local = context
            local.opacity = spec.alpha
            local.translateBy(x: spec.cx * sx, y: spec.cy * sy)
            local.rotate(by: .degrees(spec.angleDeg))
            let rect = CGRect(x: (-spec.w / 2) * sx, y: (-spec.h / 2) * sy, width: spec.w * sx, height: spec.h * sy)
            local.fill(Path(roundedRect: rect, cornerRadius: (spec.w / 2) * sx), with: .color(sparkColor))
        }
    }
}

enum PoodleMascotMode: Equatable {
    case idle
    case walking(phase: CGFloat, strideFactor: CGFloat)
    case working
    case done
}

/// Vector Floqy poodle mascot rendered from the AppIcon silhouette across Idle, Walking, Working, and Done states.
struct FloqyPoodleMascotView: View {
    let mode: PoodleMascotMode
    let width: CGFloat
    var gazeOffset: CGSize = .zero
    var isBlinking: Bool = false
    var isHappy: Bool = false
    var showSparks: Bool = false
    var isCelebrating: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isDisplayAsleep) private var isDisplayAsleep

    var body: some View {
        let height = round(width * 0.72)
        let animateLoop = mode == .working && !reduceMotion && !isDisplayAsleep
        let hopY: CGFloat = (mode == .done && !reduceMotion && !isCelebrating) ? 4 : 0
        let hopScale: CGFloat = (mode == .done && !reduceMotion && !isCelebrating) ? 0.9 : 1.0

        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !animateLoop)) { context in
            let t = animateLoop ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, canvasSize in
                drawPoodle(in: &ctx, size: canvasSize, time: t)
            }
        }
        .frame(width: width, height: height)
        .scaleEffect(hopScale, anchor: .bottom)
        .offset(y: hopY)
        .accessibilityHidden(true)
    }

    private func drawPoodle(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let sx = size.width / 64.0
        let sy = size.height / 46.0

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        func fillCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, dy: CGFloat = 0, shading: GraphicsContext.Shading) {
            let rect = CGRect(x: (cx - r) * sx, y: (cy - r + dy) * sy, width: r * 2 * sx, height: r * 2 * sy)
            context.fill(Path(ellipseIn: rect), with: shading)
        }

        func fillEllipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, dy: CGFloat = 0, shading: GraphicsContext.Shading) {
            let rect = CGRect(x: (cx - rx) * sx, y: (cy - ry + dy) * sy, width: rx * 2 * sx, height: ry * 2 * sy)
            context.fill(Path(ellipseIn: rect), with: shading)
        }

        if case .walking(let phase, let strideFactor) = mode {
            let activeStride: CGFloat = reduceMotion ? 0 : strideFactor
            let furLight = Color(red: 242 / 255, green: 148 / 255, blue: 75 / 255)
            let furMid = Color(red: 219 / 255, green: 107 / 255, blue: 39 / 255)
            let furDark = Color(red: 185 / 255, green: 75 / 255, blue: 24 / 255)
            let earTop = Color(red: 220 / 255, green: 110 / 255, blue: 41 / 255)
            let earDeep = Color(red: 158 / 255, green: 60 / 255, blue: 18 / 255)
            let snoutColor = Color(red: 244 / 255, green: 160 / 255, blue: 90 / 255)
            let noseColor = Color(red: 42 / 255, green: 21 / 255, blue: 11 / 255)
            let noseSheen = Color(red: 124 / 255, green: 81 / 255, blue: 61 / 255).opacity(0.65)
            let eyeColor = Color(red: 35 / 255, green: 16 / 255, blue: 7 / 255)
            let pawOuter = Color(red: 220 / 255, green: 110 / 255, blue: 41 / 255)
            let pawInner = Color(red: 236 / 255, green: 142 / 255, blue: 72 / 255)

            let furStops: [Gradient.Stop] = [
                .init(color: furLight, location: 0),
                .init(color: furMid, location: 0.55),
                .init(color: furDark, location: 1)
            ]

            func fillEllipseIn(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, shading: GraphicsContext.Shading) {
                let rect = CGRect(x: (cx - rx) * sx, y: (cy - ry) * sy, width: rx * 2 * sx, height: ry * 2 * sy)
                ctx.fill(Path(ellipseIn: rect), with: shading)
            }

            func fillCircleIn(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, shading: GraphicsContext.Shading) {
                fillEllipseIn(&ctx, cx, cy, r, r, shading: shading)
            }

            func drawFloqyPaw(in ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, legPhase: Double, scale: CGFloat, isFar: Bool) {
                let xShift = CGFloat(cos(legPhase)) * 3.0 * scale * activeStride
                let yLift = CGFloat(max(0, sin(legPhase))) * 3.2 * scale * activeStride
                let tiltDeg = CGFloat(cos(legPhase)) * 14 * activeStride

                var pawCtx = ctx
                pawCtx.translateBy(x: (x + xShift) * sx, y: (y - yLift) * sy)
                pawCtx.rotate(by: .degrees(tiltDeg))
                if isFar {
                    fillEllipseIn(&pawCtx, 0, 0, 4.5 * scale, 4.2 * scale, shading: .color(earDeep))
                    fillEllipseIn(&pawCtx, 0, -0.4 * scale, 3.3 * scale, 2.7 * scale, shading: .color(furDark))
                } else {
                    fillEllipseIn(&pawCtx, 0, 0, 5.2 * scale, 4.6 * scale, shading: .color(pawOuter))
                    fillEllipseIn(&pawCtx, 0.2 * scale, -0.5 * scale, 3.9 * scale, 3.1 * scale, shading: .color(pawInner))
                }
            }

            // Squash, stretch & gentle chubby waddle pivoted at ground contact
            let absSin = CGFloat(abs(sin(phase)))
            let hopY = -absSin * 2.1 * activeStride
            let sxSquash = 1.0 + (0.04 - absSin * 0.06) * activeStride
            let syStretch = 1.0 + (-0.04 + absSin * 0.06) * activeStride
            let waddleDeg = CGFloat(sin(phase)) * 2.4 * activeStride

            var bodyCtx = context
            bodyCtx.translateBy(x: 31 * sx, y: (43 + hopY) * sy)
            bodyCtx.rotate(by: .degrees(waddleDeg))
            bodyCtx.scaleBy(x: sxSquash, y: syStretch)
            bodyCtx.translateBy(x: -31 * sx, y: -43 * sy)

            // Wagging curly pom-pom tail
            let tailWag = CGFloat(sin(phase * 1.45 + 0.4)) * 15 * (0.35 + 0.65 * activeStride)
            var tailCtx = bodyCtx
            tailCtx.translateBy(x: 14.5 * sx, y: 27.5 * sy)
            tailCtx.rotate(by: .degrees(tailWag))
            var tailPath = Path()
            tailPath.move(to: .zero)
            tailPath.addQuadCurve(to: CGPoint(x: -4.5 * sx, y: -11.5 * sy), control: CGPoint(x: -5 * sx, y: -5.5 * sy))
            tailCtx.stroke(tailPath, with: .color(furDark), style: StrokeStyle(lineWidth: 3.8 * sx, lineCap: .round))
            fillCircleIn(&tailCtx, -4.5, -12.5, 4.8, shading: .color(furLight))

            // Far stubby paws
            drawFloqyPaw(in: &bodyCtx, x: 21.5, y: 39.2, legPhase: Double(phase) + .pi, scale: 0.92, isFar: true)
            drawFloqyPaw(in: &bodyCtx, x: 38.5, y: 39.2, legPhase: Double(phase), scale: 0.92, isFar: true)

            // Plump cloud-puff body behind the head
            let bodyGradient = GraphicsContext.Shading.radialGradient(
                Gradient(stops: furStops),
                center: CGPoint(x: 27 * sx, y: 23.75 * sy),
                startRadius: 2 * sx,
                endRadius: 21 * sx
            )
            fillEllipseIn(&bodyCtx, 25.5, 30.2, 14.2, 10.6, shading: bodyGradient)
            for (cx, cy, r) in [(CGFloat(18.0), CGFloat(29.5), CGFloat(8.2)), (28.0, 28.5, 9.8), (35.5, 29.8, 8.8)] {
                fillCircleIn(&bodyCtx, cx, cy, r, shading: bodyGradient)
            }

            // Near stubby rounded paws matching sitting pose
            drawFloqyPaw(in: &bodyCtx, x: 19.5, y: 40.0, legPhase: Double(phase), scale: 1.0, isFar: false)
            drawFloqyPaw(in: &bodyCtx, x: 36.0, y: 40.0, legPhase: Double(phase) + .pi, scale: 1.0, isFar: false)

            // 3/4 Floqy Poodle head
            let headTilt = CGFloat(sin(phase)) * 2.2 * activeStride
            let earBob = CGFloat(sin(phase - 0.7)) * 6.5 * activeStride
            var headCtx = bodyCtx
            headCtx.translateBy(x: 40.0 * sx, y: 20.5 * sy)
            headCtx.rotate(by: .degrees(headTilt))

            let earGradient = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [earTop, earDeep]),
                center: CGPoint(x: 0, y: 2 * sy),
                startRadius: 2 * sx,
                endRadius: 28 * sx
            )

            // Far curly ear cluster
            var farEarCtx = headCtx
            farEarCtx.translateBy(x: 10.5 * sx, y: -1.5 * sy)
            farEarCtx.rotate(by: .degrees(-earBob * 0.7))
            for (cx, cy, r) in [(CGFloat(0.5), CGFloat(1.0), CGFloat(4.2)), (2.0, 5.5, 4.4), (0.2, 9.5, 3.6)] {
                fillCircleIn(&farEarCtx, cx, cy, r, shading: earGradient)
            }

            // Near curly ear cluster
            var nearEarCtx = headCtx
            nearEarCtx.translateBy(x: -11.2 * sx, y: -1.2 * sy)
            nearEarCtx.rotate(by: .degrees(earBob))
            for (cx, cy, r) in [(CGFloat(0), CGFloat(0.5), CGFloat(5.2)), (-1.8, 5.8, 5.2), (-0.4, 10.8, 4.4)] {
                fillCircleIn(&nearEarCtx, cx, cy, r, shading: earGradient)
            }

            // Crown puffs & face base
            let headGradient = GraphicsContext.Shading.radialGradient(
                Gradient(stops: furStops),
                center: CGPoint(x: 0, y: -7 * sy),
                startRadius: 2 * sx,
                endRadius: 20 * sx
            )
            let walkCrown: [(CGFloat, CGFloat, CGFloat)] = [
                (0, -10.5, 7.2), (-6.8, -8.5, 5.8), (6.5, -8.2, 5.6), (-11.5, -4.5, 4.8), (10.2, -4.2, 4.5)
            ]
            for (cx, cy, r) in walkCrown {
                fillCircleIn(&headCtx, cx, cy, r, shading: headGradient)
            }
            fillEllipseIn(&headCtx, 0.5, 0.8, 13.8, 11.2, shading: headGradient)

            // Warm snout + chocolate button nose
            fillEllipseIn(&headCtx, 4.2, 5.2, 8.2, 5.4, shading: .color(snoutColor))
            fillEllipseIn(&headCtx, 5.4, 3.1, 3.2, 2.0, shading: .color(noseColor))
            fillEllipseIn(&headCtx, 4.7, 2.4, 1.0, 0.5, shading: .color(noseSheen))

            // Two 3/4 expressive eyes + blink
            let eyeScaleY: CGFloat = isBlinking ? 0.16 : 1.0
            fillEllipseIn(&headCtx, -1.2, 0.4, 2.45, 2.45 * eyeScaleY, shading: .color(eyeColor))
            fillEllipseIn(&headCtx, 10.2, 0.4, 2.15, 2.4 * eyeScaleY, shading: .color(eyeColor))
            if !isBlinking {
                fillCircleIn(&headCtx, -1.9, -0.5, 0.82, shading: .color(.white))
                fillCircleIn(&headCtx, 9.6, -0.5, 0.72, shading: .color(.white))
            }
            return
        }

        let isWorking = mode == .working && !reduceMotion
        let isDone = mode == .done || isHappy

        let breatheY: CGFloat = isWorking ? CGFloat(sin(time * 5.0)) * 0.55 : 0
        let pawLeftY: CGFloat = isWorking ? CGFloat(-sin(time * 14.0) * 1.4 - 1.4) : ((isDone && !reduceMotion) ? -2.8 : 0)
        let pawRightY: CGFloat = isWorking ? CGFloat(-sin(time * 14.0 + .pi) * 1.4 - 1.4) : ((isDone && !reduceMotion) ? -2.8 : 0)
        let eyeShiftX: CGFloat = isWorking ? CGFloat(sin(time * 2.8) * 1.6) : gazeOffset.width
        let eyeShiftY: CGFloat = isWorking ? 0.4 : gazeOffset.height

        if showSparks {
            drawSparks(in: &context, sx: sx, sy: sy, isWorking: isWorking, time: time)
        }

        let earGradient = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color(red: 220 / 255, green: 110 / 255, blue: 41 / 255),
                Color(red: 158 / 255, green: 60 / 255, blue: 18 / 255)
            ]),
            center: pt(32, 27),
            startRadius: 2 * sx,
            endRadius: 28 * sx
        )
        let earCircles: [(CGFloat, CGFloat, CGFloat)] = [
            (11.5, 28.5, 6.2), (9.5, 34.5, 5.6), (14.5, 22.5, 5.4),
            (52.5, 28.5, 6.2), (54.5, 34.5, 5.6), (49.5, 22.5, 5.4)
        ]
        for (cx, cy, r) in earCircles {
            fillCircle(cx, cy, r, dy: breatheY, shading: earGradient)
        }

        let furGradient = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color(red: 242 / 255, green: 148 / 255, blue: 75 / 255),
                Color(red: 219 / 255, green: 107 / 255, blue: 39 / 255),
                Color(red: 185 / 255, green: 75 / 255, blue: 24 / 255)
            ]),
            center: pt(32, 20),
            startRadius: 2 * sx,
            endRadius: 24 * sx
        )
        let crownPuffs: [(CGFloat, CGFloat, CGFloat)] = [
            (32, 14, 8.2), (24, 15.8, 6.8), (40, 15.8, 6.8), (18.2, 20.2, 5.8), (45.8, 20.2, 5.8)
        ]
        for (cx, cy, r) in crownPuffs {
            fillCircle(cx, cy, r, dy: breatheY, shading: furGradient)
        }
        fillEllipse(32, 28.5, 16.5, 12.5, dy: breatheY, shading: furGradient)

        // Warm snout + chocolate button nose
        fillEllipse(32, 33.5, 9.2, 6.2, dy: breatheY, shading: .color(Color(red: 244 / 255, green: 160 / 255, blue: 90 / 255)))
        fillEllipse(32, 31.3, 3.4, 2.2, dy: breatheY, shading: .color(Color(red: 42 / 255, green: 21 / 255, blue: 11 / 255)))
        fillEllipse(31.2, 30.6, 1.1, 0.55, dy: breatheY, shading: .color(Color(red: 124 / 255, green: 81 / 255, blue: 61 / 255).opacity(0.65)))

        if isDone {
            let arcColor = Color(red: 38 / 255, green: 18 / 255, blue: 9 / 255)
            for centerX in [CGFloat(23.5), CGFloat(40.5)] {
                var arc = Path()
                arc.move(to: pt(centerX - 3.0, 29.5 + breatheY))
                arc.addQuadCurve(
                    to: pt(centerX + 3.0, 29.5 + breatheY),
                    control: pt(centerX, 25.2 + breatheY)
                )
                context.stroke(arc, with: .color(arcColor), style: StrokeStyle(lineWidth: max(1.4, 2.4 * sx), lineCap: .round))
            }
        } else {
            let eyeScaleY: CGFloat = isBlinking ? 0.14 : 1.0
            let eyeColor = Color(red: 35 / 255, green: 16 / 255, blue: 7 / 255)
            for baseX in [CGFloat(23.5), CGFloat(40.5)] {
                let cx = baseX + eyeShiftX
                let cy = 28.5 + eyeShiftY + breatheY
                fillEllipse(cx, cy, 2.75, 2.75 * eyeScaleY, shading: .color(eyeColor))
                if !isBlinking {
                    fillCircle(cx - 0.8, cy - 1.1 - breatheY, 0.9, shading: .color(.white))
                }
            }
        }

        let pawOuter = Color(red: 220 / 255, green: 110 / 255, blue: 41 / 255)
        let pawInner = Color(red: 236 / 255, green: 142 / 255, blue: 72 / 255)
        fillEllipse(16.5, 40.5, 6.8, 4.4, dy: pawLeftY, shading: .color(pawOuter))
        fillEllipse(16.5, 39.8, 5.2, 3.2, dy: pawLeftY, shading: .color(pawInner))
        fillEllipse(47.5, 40.5, 6.8, 4.4, dy: pawRightY, shading: .color(pawOuter))
        fillEllipse(47.5, 39.8, 5.2, 3.2, dy: pawRightY, shading: .color(pawInner))
    }

    private func drawSparks(
        in context: inout GraphicsContext,
        sx: CGFloat,
        sy: CGFloat,
        isWorking: Bool,
        time: TimeInterval
    ) {
        let sparkColor = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
        let alphaA = isWorking ? (0.35 + 0.65 * ((sin(time * 6.0) + 1.0) * 0.5)) : ((mode == .done && !isCelebrating && !reduceMotion) ? 0.0 : 0.98)
        let alphaB = isWorking ? (0.35 + 0.65 * ((sin(time * 6.0 + .pi) + 1.0) * 0.5)) : ((mode == .done && !isCelebrating && !reduceMotion) ? 0.0 : 0.98)

        let specs: [(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, angleDeg: CGFloat, alpha: Double)] = [
            (48.8, 9.0, 5.4, 11.5, 22, alphaA),
            (56.6, 14.5, 5.0, 10.5, 42, alphaB)
        ]
        for spec in specs {
            var local = context
            local.opacity = spec.alpha
            local.translateBy(x: spec.cx * sx, y: spec.cy * sy)
            local.rotate(by: .degrees(spec.angleDeg))
            let rect = CGRect(
                x: (-spec.w / 2) * sx,
                y: (-spec.h / 2) * sy,
                width: spec.w * sx,
                height: spec.h * sy
            )
            local.fill(
                Path(roundedRect: rect, cornerRadius: (spec.w / 2) * sx),
                with: .color(sparkColor)
            )
        }
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
