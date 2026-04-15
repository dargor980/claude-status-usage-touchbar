import Foundation
import ClaudeBarApplication
import ClaudeBarDomain

@MainActor
public final class ClaudeBarViewModel: ObservableObject {
    @Published public private(set) var snapshot: ClaudeBarSnapshot
    @Published public private(set) var touchBarExperience: TouchBarExperienceSnapshot

    private let useCase: ObserveClaudeBarSnapshotUseCase
    private let touchBarExperienceUseCase: EvaluateTouchBarExperienceUseCase
    private let refreshIntervalNanoseconds: UInt64
    private var pollingTask: Task<Void, Never>?

    public init(
        useCase: ObserveClaudeBarSnapshotUseCase,
        initialSnapshot: ClaudeBarSnapshot = .empty(),
        touchBarExperienceUseCase: EvaluateTouchBarExperienceUseCase = .init(),
        initialTouchBarExperience: TouchBarExperienceSnapshot = .empty(),
        refreshIntervalSeconds: UInt64 = 2
    ) {
        self.useCase = useCase
        self.snapshot = initialSnapshot
        self.touchBarExperienceUseCase = touchBarExperienceUseCase
        self.touchBarExperience = initialTouchBarExperience
        self.refreshIntervalNanoseconds = refreshIntervalSeconds * 1_000_000_000
    }

    public func start() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: self?.refreshIntervalNanoseconds ?? 2_000_000_000)
            }
        }
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refresh() async {
        do {
            snapshot = try useCase.execute()
        } catch {
            snapshot = ClaudeBarSnapshot(
                observedAt: Date(),
                session: nil,
                currentSession: UsageGauge(
                    title: "Sesion actual",
                    consumedTokens: 0,
                    budgetTokens: 0,
                    percentage: 0,
                    resetAt: nil,
                    accuracy: .unavailable
                ),
                currentWeek: UsageGauge(
                    title: "Semana",
                    consumedTokens: 0,
                    budgetTokens: 0,
                    percentage: 0,
                    resetAt: nil,
                    accuracy: .unavailable
                ),
                task: nil,
                notices: ["No se pudo refrescar la telemetria: \(error.localizedDescription)"]
            )
        }
    }

    public func updateTouchBarExperience(frontmostApplication: FrontmostApplicationSnapshot) {
        touchBarExperience = touchBarExperienceUseCase.execute(frontmostApplication: frontmostApplication)
    }
}
