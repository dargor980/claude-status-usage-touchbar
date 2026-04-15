import XCTest
@testable import ClaudeBarApplication

final class EvaluateTouchBarExperienceUseCaseTests: XCTestCase {
    func testRecommendsThirdPartyBridgeForVSCodeForeground() {
        let useCase = EvaluateTouchBarExperienceUseCase()
        let frontmostApplication = FrontmostApplicationSnapshot(
            localizedName: "Visual Studio Code",
            bundleIdentifier: "com.microsoft.VSCode"
        )

        let snapshot = useCase.execute(frontmostApplication: frontmostApplication)

        XCTAssertEqual(snapshot.recommendedRoute, .thirdPartyTool)
        XCTAssertEqual(snapshot.routeAssessments.first(where: { $0.route == .thirdPartyTool })?.decision, .recommended)
        XCTAssertEqual(snapshot.routeAssessments.first(where: { $0.route == .experimentalPrivateAPI })?.decision, .rejected)
        XCTAssertTrue(snapshot.statusHeadline.contains("Visual Studio Code"))
    }

    func testDetectsCursorAsCodeEditorFamily() {
        let application = FrontmostApplicationSnapshot(
            localizedName: "Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92"
        )

        XCTAssertEqual(application.ide, .cursor)
        XCTAssertTrue(application.isCodeEditorFamily)
    }
}
