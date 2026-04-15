# Contratos iniciales

## Contratos implementados en el MVP

### `ClaudeActivityRepository`

Puerto de aplicacion encargado de leer actividad cruda:

- sesion activa o reciente
- tokens de sesion
- tokens semanales
- tarea activa
- ultima tarea completada
- avisos operativos

Implementacion actual:

- `ClaudeFilesystemActivityRepository`

### `UsagePolicyProviding`

Puerto para convertir consumo observado en porcentaje.

Implementaciones actuales:

- `DefaultUsagePolicyProvider`
- `JSONUsagePolicyProvider`

### `ObserveClaudeBarSnapshotUseCase`

Caso de uso que transforma actividad + politica en un `ClaudeBarSnapshot` listo para UI.

## Contrato propuesto para usage exacto

La siguiente iteracion deberia introducir un puerto separado para consultar cuota real desde la CLI:

### `ClaudeUsageProvider`

Responsabilidad:

- ejecutar `claude -p "/usage"` en modo headless
- capturar `stdout`
- parsear los datos relevantes del texto devuelto

Salida sugerida:

```json
{
  "sessionPercentage": 0.3,
  "weeklyPercentage": 0.25,
  "sessionResetAt": "2026-04-15T18:00:00Z",
  "weeklyResetAt": "2026-04-21T03:00:00Z",
  "rawOutput": "texto original del comando",
  "accuracy": "exact"
}
```

Implementacion esperada:

- `ClaudeHeadlessCLIUsageProvider`

Notas:

- no existe hoy un `--json` nativo para este comando
- el parseo debe encapsularse para tolerar cambios de formato
- si el parseo falla, la app debe poder degradar a `estimated`

## Contrato de configuracion local

Archivo: `claudebar.config.json`

```json
{
  "sessionTokenBudget": 2000000,
  "sessionWindowHours": 5,
  "weeklyTokenBudget": 12000000,
  "weeklyResetWeekday": 2
}
```

## Contrato propuesto para una fase 2

Si el parser local termina siendo fragil, el paso siguiente es extraer un helper local con estos endpoints:

- `GET /v1/status`
- `GET /v1/sessions/current`
- `GET /v1/tasks/current`
- `GET /v1/usage`

Respuesta sugerida para `GET /v1/status`:

```json
{
  "session": {
    "sessionId": "2518fb1e-3ab7-45e5-a164-0e44c40b8a82",
    "projectPath": "/Users/germancontreras/reserva horas",
    "isActive": true
  },
  "usage": {
    "sessionPercentage": 0.3,
    "weekPercentage": 0.25,
    "accuracy": "exact"
  },
  "task": {
    "title": "Implementando dashboard",
    "state": "running",
    "steps": ["Bash", "Read", "Edit"]
  }
}
```

En esta version propuesta, el bloque `usage` deberia obtenerse preferentemente desde `claude -p "/usage"` y no desde inferencia por tokens.

Fase 1 no implementa servidor HTTP; solo deja definido el contrato para desacoplar una futura extraccion de proceso.

## Contrato de fase 2 para estrategia Touch Bar

La evaluacion de Touch Bar persistente no debe expandir `ClaudeBarSnapshot`. En su lugar usa un contrato separado de aplicacion:

- `FrontmostApplicationSnapshot`: identifica la app que hoy esta al frente
- `TouchBarRouteAssessment`: compara rutas candidatas para persistencia
- `TouchBarExperienceSnapshot`: resume modo actual, recomendacion y siguiente corte

Responsabilidad:

- exponer decision tecnica sin acoplarla al dominio
- permitir que la UI nativa muestre el estado de la estrategia
- dejar listo el reemplazo del renderer Touch Bar sin reescribir gauges, sesion o tarea
