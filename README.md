<div align="center">

# claudeBar

**A native macOS MVP for surfacing Claude Code session usage and task status in a Touch Bar-friendly companion app.**

[Overview](#overview) • [Why This Exists](#why-this-exists) • [Getting Started](#getting-started) • [Configuration](#configuration) • [Architecture](#architecture) • [Roadmap](#roadmap)

</div>

claudeBar is an early product prototype aimed at MacBook Pro users running Claude Code CLI who want instant visibility into the current session without interrupting their flow. The app reads local Claude telemetry, estimates usage against configurable budgets, shows the latest active session, and surfaces the current or last completed task in a lightweight native interface.

## Overview

This repository contains a native macOS app built with `Swift`, `AppKit`, and `SwiftUI`. The app currently ships as a Swift Package executable and is organized to keep business logic, infrastructure concerns, and presentation separated from the start.

The MVP focuses on four things:

- Detect the latest Claude Code session from local filesystem data.
- Display current session usage and weekly usage as progress bars.
- Show the active task when Claude is working, or the last completed task when it finishes.
- Mirror the same state in a desktop panel and a Touch Bar-capable UI surface.

## Why This Exists

Claude Code exposes valuable runtime context, but not in a form that is instantly visible while coding. The goal of claudeBar is to reduce that friction and test whether a glanceable, native macOS companion is enough to make Claude usage feel more operational and less opaque.

> [!NOTE]
> The app now supports an exact-usage path when it can read a local `rate_limits` capture from Claude Code status line scripts. If that source is missing or invalid, it falls back to estimated usage from local token telemetry and configured budgets.

> [!WARNING]
> The app currently uses public `AppKit` APIs for Touch Bar support. That means the Touch Bar UI is tied to the app lifecycle and does not yet provide a guaranteed persistent bar while another app such as VS Code is in the foreground.

> [!IMPORTANT]
> The chosen Phase 2 direction is to keep the current `AppKit` Touch Bar as an internal fallback and deliver persistent visibility through a third-party Touch Bar host, starting with `BetterTouchTool`, while `claudeBar` remains the telemetry and action source.

## Getting Started

### Requirements

- macOS 13 or later
- Swift 5.10
- Apple Command Line Tools
- A local Claude Code environment with telemetry available under `~/.claude`

### Build

```bash
CLANG_MODULE_CACHE_PATH=$PWD/.build/module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=$PWD/.build/module-cache \
/Library/Developer/CommandLineTools/usr/bin/swift build --scratch-path $PWD/.build/scratch
```

### Run

```bash
open .build/scratch/arm64-apple-macosx/debug/claudebar
```

The app launches as a small native companion with a dashboard window, a status bar item, and a Touch Bar provider backed by the same snapshot state.

## Configuration

Usage estimation is controlled by [`claudebar.config.json`](./claudebar.config.json):

```json
{
  "sessionTokenBudget": 2000000,
  "sessionWindowHours": 5,
  "weeklyTokenBudget": 12000000,
  "weeklyResetWeekday": 2
}
```

These values define the assumed budget and reset windows used to compute the progress bars. `weeklyResetWeekday` follows the `Calendar` weekday index used on macOS, where `1 = Sunday`, `2 = Monday`, and so on.

## How It Works

claudeBar reads from local Claude files instead of scraping UI output:

- `~/.claude/history.jsonl` to identify the most recent session.
- `~/.claude/projects/**/*.jsonl` to collect tokens, recent steps, background task events, and remote session URLs.
- `~/.claude/tasks/<sessionId>/*.json` to detect tasks currently marked `in_progress`.
- `~/.claude/stats-cache.json` to build the weekly aggregate.
- `~/.claude/ide/*.lock` to identify the connected IDE.

The repository converts those sources into a single `ClaudeBarSnapshot`, which the app refreshes on a short polling interval and renders consistently across the desktop panel and Touch Bar UI.

For more exact usage, the app can also read `~/.claude/claudebar-statusline.json` when you wire Claude Code status line to the helper script at [scripts/claudebar_statusline_capture.py](/Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_statusline_capture.py:1). The capture path can be overridden with `CLAUDEBAR_STATUSLINE_CAPTURE_PATH`.

## Architecture

The codebase is intentionally split by responsibility:

- `Sources/ClaudeBarDomain` contains immutable models and shared value types.
- `Sources/ClaudeBarApplication` contains use cases and ports.
- `Sources/ClaudeBarInfrastructure` contains filesystem-backed telemetry parsing and configuration adapters.
- `Sources/ClaudeBarPresentation` contains the view model and SwiftUI views.
- `Sources/ClaudeBarApp` contains AppKit composition, lifecycle wiring, the status item, and Touch Bar integration.

This structure keeps the parsing logic independent from the UI and leaves space for a future daemon, helper process, or more accurate quota provider without forcing a rewrite of the presentation layer.

## Project Status

This is an MVP, not a finished utility. The current version validates the shape of the product and the viability of the local telemetry approach. The biggest open technical questions are:

- how to replace estimated usage with a more exact source of quota data
- how to harden the local parsers with fixture-driven integration coverage

The Touch Bar direction is now defined at the architecture level: bridge `claudeBar` into an external Touch Bar controller instead of pursuing a private API implementation inside the app.

As of `Claude Code 2.1.108` on April 15, 2026, `claude -p "/usage"` returns `Unknown command: /usage` in this environment, so the current exact-usage integration prefers status line `rate_limits` capture and keeps the headless `/usage` probe as an experimental fallback.

## Roadmap

The current roadmap is staged in small product increments:

1. Base functional telemetry and native UI shell.
2. Better Touch Bar behavior beyond app focus.
3. More accurate usage calculation.
4. Packaging, startup integration, diagnostics, and multi-session support.

See the supporting design docs for the detailed breakdown:

- [Architecture](./docs/ARCHITECTURE.md)
- [Data Model](./docs/DATA_MODEL.md)
- [Contracts](./docs/CONTRACTS.md)
- [Technical Roadmap](./docs/ROADMAP.md)
- [Touch Bar Strategy](./docs/TOUCH_BAR_STRATEGY.md)

## Development Notes

- The app currently builds successfully with `swift build` in this environment.
- `swift test` is not available with the current Command Line Tools installation because `XCTest` is missing from the local toolchain setup.
- Repository guidelines for future contributors live in [AGENTS.md](./AGENTS.md).
