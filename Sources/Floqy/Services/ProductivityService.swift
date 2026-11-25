import Combine
import Foundation

/// Manages persistent local Todo items and the Pomodoro Focus timer.
@MainActor
final class ProductivityService: ObservableObject {
    private static let durationMinutesDefaultsKey = "floqy.pomodoro.durationMinutes"

    @Published private(set) var todos: [TodoItem] = []
    @Published private(set) var pomodoro: PomodoroState

    var onPomodoroStarted: (() -> Void)?
    var onPomodoroCompleted: (() -> Void)?

    private var timer: Timer?
    private let storageURL: URL

    init() {
        let savedMinutes = UserDefaults.standard.integer(forKey: Self.durationMinutesDefaultsKey)
        let initialMinutes = savedMinutes > 0 ? savedMinutes : PomodoroState.defaultDurationMinutes
        self.pomodoro = PomodoroState(durationMinutes: initialMinutes)

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.storageURL = appSupport
            .appendingPathComponent("Floqy", isDirectory: true)
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
    }

    func togglePomodoro() {
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
    }

    func resetPomodoro() {
        timer?.invalidate()
        timer = nil
        pomodoro.reset()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let completed = self.pomodoro.tick()
                if completed {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.onPomodoroCompleted?()
                }
            }
        }
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
