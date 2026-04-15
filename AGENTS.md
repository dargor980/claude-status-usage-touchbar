# Repository Guidelines

## Project Structure & Module Organization
The codebase is a single Swift Package that isolates responsibilities by layer instead of by feature slice. `Sources/ClaudeBarDomain` holds immutable models such as `ClaudeBarSnapshot`, `UsageGauge`, and `TaskSnapshot`. `Sources/ClaudeBarApplication` contains ports and the snapshot assembly use case. `Sources/ClaudeBarInfrastructure` owns local Claude filesystem parsing and JSON-backed quota policy loading. `Sources/ClaudeBarPresentation` contains the polling view model plus SwiftUI views shared by the desktop panel and Touch Bar strip. `Sources/ClaudeBarApp` is the composition root for AppKit lifecycle, status item, window wiring, and Touch Bar registration. Architecture notes and product planning live under `docs/`.

## Build, Test, and Development Commands
Use the local workspace cache paths when building because SwiftPM cannot write to the default home cache under the current environment:
`CLANG_MODULE_CACHE_PATH=$PWD/.build/module-cache SWIFTPM_MODULECACHE_OVERRIDE=$PWD/.build/module-cache /Library/Developer/CommandLineTools/usr/bin/swift build --scratch-path $PWD/.build/scratch`
Launch the built app with:
`open .build/scratch/arm64-apple-macosx/debug/claudebar`
`swift test` is not currently available in this Command Line Tools installation because XCTest is missing from the environment.

## Coding Style & Naming Conventions
Follow the existing layered naming: nouns for domain models, `...Repository` and `...Provider` for ports/adapters, and `...UseCase` for orchestration. Keep parsing logic in infrastructure and keep `Foundation`-heavy code out of `ClaudeBarDomain`. Prefer small, immutable structs for snapshot payloads and keep AppKit-specific code inside `ClaudeBarApp`.

## Testing Guidelines
Place pure logic tests in `Tests/ClaudeBarApplicationTests`. Prioritize use case math and parser fixtures before UI coverage. Because XCTest is unavailable in the current CLT setup, treat tests as authored but not runnable until Xcode or a full XCTest-capable toolchain is installed.

## Commit & Pull Request Guidelines
Git history currently contains only the bootstrap `Initial commit`, so there is no mature repository-specific pattern yet. Use Conventional Commits going forward and keep each PR scoped to one vertical slice: telemetry, presentation, or packaging.
