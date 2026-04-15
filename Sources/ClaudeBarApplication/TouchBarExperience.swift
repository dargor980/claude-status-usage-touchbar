import Foundation

public enum FrontmostIDE: String, Equatable, Sendable {
    case visualStudioCode
    case cursor
    case windsurf
    case zed
    case xcode
    case terminal
    case other
    case unknown
}

public struct FrontmostApplicationSnapshot: Equatable, Sendable {
    public let localizedName: String
    public let bundleIdentifier: String?
    public let ide: FrontmostIDE

    public init(localizedName: String, bundleIdentifier: String?) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.ide = FrontmostApplicationSnapshot.detectIDE(
            localizedName: localizedName,
            bundleIdentifier: bundleIdentifier
        )
    }

    public var isCodeEditorFamily: Bool {
        switch ide {
        case .visualStudioCode, .cursor, .windsurf, .zed:
            return true
        default:
            return false
        }
    }

    public static func unknown() -> FrontmostApplicationSnapshot {
        FrontmostApplicationSnapshot(localizedName: "App desconocida", bundleIdentifier: nil)
    }

    private static func detectIDE(localizedName: String, bundleIdentifier: String?) -> FrontmostIDE {
        let normalizedName = localizedName.lowercased()
        let normalizedBundleIdentifier = bundleIdentifier?.lowercased() ?? ""

        if normalizedBundleIdentifier.contains("com.microsoft.vscode") || normalizedName.contains("visual studio code") {
            return .visualStudioCode
        }

        if normalizedBundleIdentifier.contains("cursor") || normalizedName == "cursor" {
            return .cursor
        }

        if normalizedBundleIdentifier.contains("windsurf") || normalizedName.contains("windsurf") {
            return .windsurf
        }

        if normalizedBundleIdentifier.contains("zed") || normalizedName == "zed" {
            return .zed
        }

        if normalizedBundleIdentifier == "com.apple.dt.xcode" || normalizedName == "xcode" {
            return .xcode
        }

        if normalizedBundleIdentifier.contains("terminal")
            || normalizedBundleIdentifier.contains("iterm")
            || normalizedName.contains("terminal")
            || normalizedName.contains("iterm")
        {
            return .terminal
        }

        if normalizedName.isEmpty && normalizedBundleIdentifier.isEmpty {
            return .unknown
        }

        return .other
    }
}

public enum TouchBarCurrentImplementation: String, Equatable, Sendable {
    case publicAppKitMirror
}

public enum TouchBarCandidateRoute: String, CaseIterable, Equatable, Sendable {
    case experimentalPrivateAPI
    case companionAutomation
    case thirdPartyTool
}

public enum TouchBarPersistenceLevel: String, Equatable, Sendable {
    case focusBound
    case partial
    case persistent
}

public enum TouchBarCostLevel: String, Equatable, Sendable {
    case low
    case medium
    case high
}

public enum TouchBarRouteDecision: String, Equatable, Sendable {
    case recommended
    case deferred
    case rejected
}

public struct TouchBarRouteAssessment: Equatable, Sendable {
    public let route: TouchBarCandidateRoute
    public let title: String
    public let summary: String
    public let persistence: TouchBarPersistenceLevel
    public let risk: TouchBarCostLevel
    public let maintenance: TouchBarCostLevel
    public let decision: TouchBarRouteDecision
    public let nextStep: String

    public init(
        route: TouchBarCandidateRoute,
        title: String,
        summary: String,
        persistence: TouchBarPersistenceLevel,
        risk: TouchBarCostLevel,
        maintenance: TouchBarCostLevel,
        decision: TouchBarRouteDecision,
        nextStep: String
    ) {
        self.route = route
        self.title = title
        self.summary = summary
        self.persistence = persistence
        self.risk = risk
        self.maintenance = maintenance
        self.decision = decision
        self.nextStep = nextStep
    }
}

public struct TouchBarExperienceSnapshot: Equatable, Sendable {
    public let currentImplementation: TouchBarCurrentImplementation
    public let currentImplementationTitle: String
    public let currentImplementationSummary: String
    public let frontmostApplication: FrontmostApplicationSnapshot
    public let statusHeadline: String
    public let decisionSummary: String
    public let recommendedRoute: TouchBarCandidateRoute
    public let nextImplementationSteps: [String]
    public let routeAssessments: [TouchBarRouteAssessment]

    public init(
        currentImplementation: TouchBarCurrentImplementation,
        currentImplementationTitle: String,
        currentImplementationSummary: String,
        frontmostApplication: FrontmostApplicationSnapshot,
        statusHeadline: String,
        decisionSummary: String,
        recommendedRoute: TouchBarCandidateRoute,
        nextImplementationSteps: [String],
        routeAssessments: [TouchBarRouteAssessment]
    ) {
        self.currentImplementation = currentImplementation
        self.currentImplementationTitle = currentImplementationTitle
        self.currentImplementationSummary = currentImplementationSummary
        self.frontmostApplication = frontmostApplication
        self.statusHeadline = statusHeadline
        self.decisionSummary = decisionSummary
        self.recommendedRoute = recommendedRoute
        self.nextImplementationSteps = nextImplementationSteps
        self.routeAssessments = routeAssessments
    }

    public static func empty() -> TouchBarExperienceSnapshot {
        TouchBarExperienceSnapshot(
            currentImplementation: .publicAppKitMirror,
            currentImplementationTitle: "AppKit publico",
            currentImplementationSummary: "La Touch Bar actual replica el dashboard, pero depende de que claudeBar este en la cadena activa de respuesta.",
            frontmostApplication: .unknown(),
            statusHeadline: "Sin datos sobre la app al frente.",
            decisionSummary: "La estrategia persistente todavia no esta evaluada.",
            recommendedRoute: .thirdPartyTool,
            nextImplementationSteps: [],
            routeAssessments: []
        )
    }
}

public struct EvaluateTouchBarExperienceUseCase {
    public init() {}

    public func execute(frontmostApplication: FrontmostApplicationSnapshot) -> TouchBarExperienceSnapshot {
        let routeAssessments = [
            TouchBarRouteAssessment(
                route: .experimentalPrivateAPI,
                title: "API privada experimental",
                summary: "Puede insertar items globales en la Touch Bar fuera del foco normal, pero depende de frameworks privados y queda expuesta a cambios de macOS.",
                persistence: .persistent,
                risk: .high,
                maintenance: .high,
                decision: .rejected,
                nextStep: "No avanzar salvo que todas las rutas publicas o integraciones externas fallen."
            ),
            TouchBarRouteAssessment(
                route: .companionAutomation,
                title: "Companion app con automatizacion",
                summary: "Sirve para desacoplar el payload y automatizar sincronizacion, pero por si sola no resuelve la persistencia si el render sigue en Touch Bar publica de AppKit.",
                persistence: .partial,
                risk: .medium,
                maintenance: .medium,
                decision: .deferred,
                nextStep: "Mantener esta ruta como patron de bridge interno, no como mecanismo de render final."
            ),
            TouchBarRouteAssessment(
                route: .thirdPartyTool,
                title: "Integracion con herramienta de terceros",
                summary: "Delega el render persistente a una herramienta que ya controla la Touch Bar y deja a claudeBar como proveedor de estado y acciones.",
                persistence: .persistent,
                risk: .medium,
                maintenance: .medium,
                decision: .recommended,
                nextStep: "Publicar un payload estable y probar primero con BetterTouchTool; mantener MTMR como alternativa secundaria."
            ),
        ]

        return TouchBarExperienceSnapshot(
            currentImplementation: .publicAppKitMirror,
            currentImplementationTitle: "AppKit publico",
            currentImplementationSummary: "La implementacion actual es util como espejo local y fallback, pero no puede garantizar visibilidad persistente cuando otra app tiene el foco.",
            frontmostApplication: frontmostApplication,
            statusHeadline: statusHeadline(for: frontmostApplication),
            decisionSummary: "Ruta recomendada: integrar un bridge hacia una herramienta de terceros que ya pueda mostrar widgets globales en la Touch Bar, manteniendo a claudeBar como fuente de verdad y dejando AppKit como fallback interno.",
            recommendedRoute: .thirdPartyTool,
            nextImplementationSteps: [
                "Definir un payload local estable para Touch Bar con sesion, gauges y CTA de resume.",
                "Generar un bridge inicial para BetterTouchTool con widgets actualizables via script o URL scheme.",
                "Mantener la Touch Bar publica actual como modo espejo y diagnostico dentro de la app.",
            ],
            routeAssessments: routeAssessments
        )
    }

    private func statusHeadline(for application: FrontmostApplicationSnapshot) -> String {
        if application.isCodeEditorFamily {
            return "\(application.localizedName) esta al frente; la Touch Bar publica de claudeBar no puede quedarse visible de forma persistente en ese escenario."
        }

        if application.ide == .unknown {
            return "La app al frente no pudo detectarse; el modo actual sigue limitado al foco de claudeBar."
        }

        return "\(application.localizedName) esta al frente; la implementacion actual sigue siendo dependiente del foco de claudeBar."
    }
}
