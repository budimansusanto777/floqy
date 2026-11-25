import Combine
import Foundation

/// Manages persistent local Todo items and the Pomodoro Focus timer.
@MainActor
final class ProductivityService: ObservableObject {
    private static let durationMinutesDefaultsKey = "floqy.pomodoro.durationMinutes"
    private static let completedSessionsCountDefaultsKey = "floqy.pomodoro.completedSessionsCount"
    private static let completedSessionsDayDefaultsKey = "floqy.pomodoro.completedSessionsDay"

    @Published private(set) var todos: [TodoItem] = []
    @Published private(set) var pomodoro: PomodoroState
    @Published private(set) var completedSessionsToday: Int = 0

    var currentRoundNumber: Int {
        PomodoroState.currentRound(completedSessions: completedSessionsToday)
    }

    var lastCompletedRoundNumber: Int {
        PomodoroState.lastCompletedRound(completedSessions: completedSessionsToday)
    }

    var onPomodoroStarted: (() -> Void)?
    var onPomodoroStateChanged: (() -> Void)?
    var onPomodoroCompleted: (() -> Void)?

    private var timer: Timer?
    private let storageURL: URL
    private var completedSessionsDayKey: String

    init() {
        let savedMinutes = UserDefaults.standard.integer(forKey: Self.durationMinutesDefaultsKey)
        let initialMinutes = savedMinutes > 0 ? savedMinutes : PomodoroState.defaultDurationMinutes
        self.pomodoro = PomodoroState(durationMinutes: initialMinutes)

        let todayKey = CalendarLogic.dayKey(for: Date())
        self.completedSessionsDayKey = todayKey
        if UserDefaults.standard.string(forKey: Self.completedSessionsDayDefaultsKey) == todayKey {
            self.completedSessionsToday = max(0, UserDefaults.standard.integer(forKey: Self.completedSessionsCountDefaultsKey))
        }

        self.storageURL = FileManager.floqySupportDirectory
            .appendingPathComponent("todos.json")
        loadTodos()
    }

    // MARK: - Pomodoro

    func setPomodoroDuration(minutes: Int) {
        let clamped = min(PomodoroState.maxDurationMinutes, max(PomodoroState.minDurationMinutes, minutes))
        UserDefaults.standard.set(clamped, forKey: Self.durationMinutesDefaultsKey)
        timer?.invalidate()
        timer = nil
        pomodoro.setDuration(minutes: clamped)
        onPomodoroStateChanged?()
    }

    func togglePomodoro() {
        syncSessionDayIfNeeded()
        pomodoro.isRunning.toggle()
        if pomodoro.isRunning {
            if pomodoro.remainingSeconds <= 0 {
                pomodoro.remainingSeconds = pomodoro.durationSeconds
            }
            onPomodoroStarted?()
            startTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
        onPomodoroStateChanged?()
    }

    func resetPomodoro() {
        syncSessionDayIfNeeded()
        let alreadyAtStart = pomodoro.isAtInitialStart
        timer?.invalidate()
        timer = nil
        pomodoro.reset()
        if alreadyAtStart && completedSessionsToday > 0 {
            completedSessionsToday = 0
            saveCompletedSessions()
        }
        onPomodoroStateChanged?()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let completed = self.pomodoro.tick()
                if completed {
                    self.syncSessionDayIfNeeded()
                    self.completedSessionsToday += 1
                    self.saveCompletedSessions()
                    self.timer?.invalidate()
                    self.timer = nil
                    self.onPomodoroCompleted?()
                }
            }
        }
    }

    private func syncSessionDayIfNeeded() {
        let todayKey = CalendarLogic.dayKey(for: Date())
        guard completedSessionsDayKey != todayKey else { return }
        completedSessionsDayKey = todayKey
        completedSessionsToday = 0
        saveCompletedSessions()
    }

    private func saveCompletedSessions() {
        UserDefaults.standard.set(completedSessionsToday, forKey: Self.completedSessionsCountDefaultsKey)
        UserDefaults.standard.set(completedSessionsDayKey, forKey: Self.completedSessionsDayDefaultsKey)
    }

    // MARK: - Todos

    func addTodo(_ rawTitle: String) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        todos.insert(TodoItem(title: title), at: 0)
        saveTodos()
    }

    func toggleTodo(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isDone.toggle()
        saveTodos()
    }

    func deleteTodo(id: UUID) {
        todos.removeAll { $0.id == id }
        saveTodos()
    }

    private func loadTodos() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return
        }
        todos = decoded
    }

    private func saveTodos() {
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(todos) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
