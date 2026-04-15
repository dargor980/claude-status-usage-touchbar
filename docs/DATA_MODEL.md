# Modelo de datos inicial

## `SessionSnapshot`

Representa la sesion observada.

- `sessionId`
- `projectPath`
- `currentWorkingDirectory`
- `startedAt`
- `lastActivityAt`
- `isActive`
- `ideName`
- `remoteURL`

## `UsageGauge`

Representa una barra de uso.

- `title`
- `consumedTokens`
- `budgetTokens`
- `percentage`
- `resetAt`
- `accuracy`

Se usa dos veces en el snapshot final:

- `currentSession`
- `currentWeek`

## `TaskSnapshot`

Describe la tarea visible para el usuario.

- `title`
- `detail`
- `state`: `idle | running | completed`
- `source`: `plan | background | telemetry`
- `steps`
- `startedAt`
- `finishedAt`

## `ClaudeBarSnapshot`

Contrato de lectura para presentacion.

- `observedAt`
- `session`
- `currentSession`
- `currentWeek`
- `task`
- `notices`

## `UsagePolicy`

Configura el calculo del porcentaje estimado.

- `sessionTokenBudget`
- `sessionWindowHours`
- `weeklyTokenBudget`
- `weeklyResetWeekday`

