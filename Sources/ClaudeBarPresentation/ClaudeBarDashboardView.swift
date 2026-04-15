import SwiftUI
import ClaudeBarDomain
import ClaudeBarApplication

public struct ClaudeBarDashboardView: View {
    @ObservedObject private var viewModel: ClaudeBarViewModel
    private let onRefresh: () -> Void
    private let onResume: () -> Void

    public init(
        viewModel: ClaudeBarViewModel,
        onRefresh: @escaping () -> Void,
        onResume: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onRefresh = onRefresh
        self.onResume = onResume
    }

    public var body: some View {
        let snapshot = viewModel.snapshot
        let touchBarExperience = viewModel.touchBarExperience

        VStack(alignment: .leading, spacing: 20) {
            header(snapshot: snapshot)

            HStack(spacing: 16) {
                gaugeCard(snapshot.currentSession)
                gaugeCard(snapshot.currentWeek)
            }

            sessionCard(snapshot: snapshot)
            taskCard(snapshot: snapshot)
            touchBarStrategyCard(touchBarExperience)

            if !snapshot.notices.isEmpty {
                noticeCard(snapshot.notices)
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 520)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.90, green: 0.94, blue: 0.97),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func header(snapshot: ClaudeBarSnapshot) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("claudeBar")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Monitor local para Touch Bar sobre sesiones de Claude Code CLI.")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Actualizado \(relative(snapshot.observedAt))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button("Refresh", action: onRefresh)
                    .buttonStyle(.bordered)

                Button("Resume", action: onResume)
                    .buttonStyle(.borderedProminent)
                    .disabled(snapshot.session?.remoteURL == nil)
            }
        }
    }

    private func gaugeCard(_ gauge: UsageGauge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(gauge.title)
                    .font(.title3.weight(.semibold))

                Spacer()

                accuracyBadge(gauge.accuracy)
            }

            ProgressView(value: gauge.clampedPercentage)
                .tint(Color(red: 0.08, green: 0.43, blue: 0.84))
                .scaleEffect(x: 1, y: 1.6, anchor: .center)

            HStack(alignment: .lastTextBaseline) {
                Text(percent(gauge.clampedPercentage))
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(gaugeDetailText(gauge))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(resetText(gauge.resetAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sessionCard(snapshot: ClaudeBarSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sesion observada")
                .font(.title3.weight(.semibold))

            if let session = snapshot.session {
                infoLine("Session ID", session.sessionId)
                infoLine("Proyecto", session.projectPath)
                infoLine("CWD", session.currentWorkingDirectory)
                infoLine("IDE", session.ideName ?? "No detectado")
                infoLine("Estado", session.isActive ? "Activa" : "Sin actividad reciente")
                infoLine("Inicio", absolute(session.startedAt))
                infoLine("Ultima actividad", relative(session.lastActivityAt))
            } else {
                Text("No hay una sesion reciente disponible.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func taskCard(snapshot: ClaudeBarSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tarea")
                .font(.title3.weight(.semibold))

            if let task = snapshot.task {
                HStack {
                    Circle()
                        .fill(task.state == .running ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)

                    Text(task.title)
                        .font(.headline)

                    Spacer()

                    Text(task.state.rawValue.capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let detail = task.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                if !task.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pasos recientes")
                            .font(.subheadline.weight(.semibold))

                        ForEach(task.steps.prefix(3), id: \.self) { step in
                            Text("• \(step)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let finishedAt = task.finishedAt, task.state == .completed {
                    Text("Finalizada \(relative(finishedAt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sin tarea activa ni finalizacion reciente.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func touchBarStrategyCard(_ experience: TouchBarExperienceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Touch Bar real")
                        .font(.title3.weight(.semibold))

                    Text(experience.statusHeadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                decisionBadge(.recommended)
            }

            infoLine("App al frente", experience.frontmostApplication.localizedName)
            infoLine("Modo actual", experience.currentImplementationTitle)

            Text(experience.currentImplementationSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(experience.decisionSummary)
                .font(.subheadline.weight(.medium))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(experience.routeAssessments, id: \.route.rawValue) { route in
                    routeAssessmentRow(route)
                }
            }

            if !experience.nextImplementationSteps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Siguiente corte")
                        .font(.subheadline.weight(.semibold))

                    ForEach(experience.nextImplementationSteps, id: \.self) { step in
                        Text("• \(step)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func noticeCard(_ notices: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notas")
                .font(.headline)

            ForEach(notices, id: \.self) { notice in
                Text("• \(notice)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }

    private func accuracyBadge(_ accuracy: UsageAccuracy) -> some View {
        Text(accuracy.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.85), in: Capsule())
    }

    private func routeAssessmentRow(_ route: TouchBarRouteAssessment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(route.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                decisionBadge(route.decision)
            }

            Text(route.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Persistencia: \(label(for: route.persistence)) · Riesgo: \(label(for: route.risk)) · Mantencion: \(label(for: route.maintenance))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(route.nextStep)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func decisionBadge(_ decision: TouchBarRouteDecision) -> some View {
        Text(label(for: decision))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(decisionColor(decision).opacity(0.16), in: Capsule())
            .foregroundStyle(decisionColor(decision))
    }

    private func label(for decision: TouchBarRouteDecision) -> String {
        switch decision {
        case .recommended:
            return "Recomendada"
        case .deferred:
            return "Postergada"
        case .rejected:
            return "Descartada"
        }
    }

    private func label(for persistence: TouchBarPersistenceLevel) -> String {
        switch persistence {
        case .focusBound:
            return "atada al foco"
        case .partial:
            return "parcial"
        case .persistent:
            return "persistente"
        }
    }

    private func label(for level: TouchBarCostLevel) -> String {
        switch level {
        case .low:
            return "bajo"
        case .medium:
            return "medio"
        case .high:
            return "alto"
        }
    }

    private func decisionColor(_ decision: TouchBarRouteDecision) -> Color {
        switch decision {
        case .recommended:
            return Color(red: 0.11, green: 0.53, blue: 0.28)
        case .deferred:
            return Color(red: 0.74, green: 0.46, blue: 0.09)
        case .rejected:
            return Color(red: 0.70, green: 0.17, blue: 0.15)
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func gaugeDetailText(_ gauge: UsageGauge) -> String {
        if gauge.accuracy == .exact || gauge.budgetTokens <= 0 {
            return "Porcentaje exacto desde Claude Code"
        }

        return "\(gauge.consumedTokens.formatted()) / \(max(gauge.budgetTokens, 0).formatted()) tokens"
    }

    private func resetText(_ date: Date?) -> String {
        guard let date else { return "Sin fecha de reinicio" }
        return "Reinicia \(relative(date))"
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func absolute(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

public struct TouchBarStripView: View {
    private let snapshot: ClaudeBarSnapshot
    private let onResume: () -> Void

    public init(snapshot: ClaudeBarSnapshot, onResume: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onResume = onResume
    }

    public var body: some View {
        HStack(spacing: 8) {
            gaugeChip(snapshot.currentSession)
            gaugeChip(snapshot.currentWeek)
            Spacer(minLength: 4)
            resumeChip
        }
        .padding(.horizontal, 8)
        // Clear background so the Touch Bar's native dark surface shows through.
        .background(Color.clear)
    }

    // MARK: - Gauge chip

    private func gaugeChip(_ gauge: UsageGauge) -> some View {
        HStack(spacing: 5) {
            Text(gauge.title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            miniBar(gauge.clampedPercentage)

            Text(gauge.clampedPercentage.formatted(.percent.precision(.fractionLength(0))))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(percentColor(gauge.clampedPercentage))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func miniBar(_ value: Double) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.15))
                .frame(width: 36, height: 4)
            RoundedRectangle(cornerRadius: 2)
                .fill(percentColor(value))
                .frame(width: max(2, 36 * value), height: 4)
        }
    }

    private func percentColor(_ value: Double) -> Color {
        if value >= 0.85 { return Color(red: 1.0, green: 0.35, blue: 0.35) }
        if value >= 0.65 { return Color(red: 1.0, green: 0.80, blue: 0.25) }
        return Color(red: 0.35, green: 0.85, blue: 0.55)
    }

    // MARK: - Resume chip

    private var resumeChip: some View {
        Button(action: onResume) {
            HStack(spacing: 4) {
                Text(resumeLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var resumeLabel: String {
        if let task = snapshot.task, task.state == .running {
            let title = task.title
            return title.count > 22 ? String(title.prefix(22)) + "..." : title
        }
        return snapshot.session != nil ? "Resume" : "claudeBar"
    }
}
