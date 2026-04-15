# Arquitectura del MVP

## Decisiones principales

### 1. App nativa con `Swift + AppKit + SwiftUI`

La Touch Bar y la lectura de archivos locales de `~/.claude` piden integracion fuerte con macOS. `AppKit` resuelve ciclo de vida, status item y Touch Bar; `SwiftUI` acelera el panel espejo para validar el producto.

### 2. Arquitectura limpia en cinco capas

- `ClaudeBarDomain`: entidades puras y value objects
- `ClaudeBarApplication`: casos de uso y puertos
- `ClaudeBarInfrastructure`: lectura de filesystem y politicas configurables
- `ClaudeBarPresentation`: view model y vistas
- `ClaudeBarApp`: composicion, status item, ventana y Touch Bar

La regla es unidireccional: la infraestructura depende de aplicacion y dominio; la UI depende de aplicacion y dominio; el punto de entrada solo ensambla dependencias.

### 3. Dos fuentes locales separadas

- `history.jsonl` y `projects/**/*.jsonl`: sesion observada, tokens, pasos recientes y tareas en background
- `tasks/<sessionId>/*.json`: tareas planificadas con `in_progress`
- `stats-cache.json`: agregacion semanal
- `ide/*.lock`: IDE conectado

Separar estas fuentes evita mezclar concernes de cuota, sesion y task tracking.

## Flujo del MVP

1. `ClaudeFilesystemActivityRepository` detecta la sesion reciente.
2. Lee su `jsonl`, suma tokens y extrae pasos/tareas.
3. Cruza la sesion con `stats-cache.json` para el acumulado semanal.
4. `ObserveClaudeBarSnapshotUseCase` convierte la actividad en `ClaudeBarSnapshot`.
5. `ClaudeBarViewModel` refresca cada 2 segundos.
6. La ventana y la Touch Bar consumen el mismo snapshot.

## Decisiones conscientes para validar rapido

- El porcentaje de uso no intenta emular `/usage` a ciegas; usa presupuestos configurables.
- La Touch Bar usa solo API publica de AppKit. Eso permite compilar y probar hoy, aunque no cubre todavia el caso “visible mientras VS Code esta al frente”.
- El refresco es por polling simple. Cambiar a `FSEvents` o `DispatchSourceFileSystemObject` queda para una segunda iteracion si la frecuencia de 2 segundos no basta.

## Decision de fase 2 para Touch Bar persistente

La comparacion tecnica de fase 2 deja una conclusion clara:

- `AppKit` publico se mantiene como espejo interno y fallback.
- API privada experimental queda descartada por riesgo de plataforma y mantenibilidad.
- companion app con automatizacion queda como patron de bridge, no como renderer final.
- la siguiente implementacion persistente debe integrarse con una herramienta de terceros que ya controle la Touch Bar, empezando por `BetterTouchTool`.

La consecuencia arquitectonica es simple: `claudeBar` pasa a ser proveedor de estado para dos superficies:

- UI nativa propia
- host persistente externo de Touch Bar

El contrato de dominio no cambia. Lo que cambia es el adaptador de salida.

Ver detalle en [TOUCH_BAR_STRATEGY.md](./TOUCH_BAR_STRATEGY.md).

### Corte implementado

La primera implementacion concreta del host externo usa un bridge por archivo:

- `claudeBar` escribe `~/.claude/claudebar-touchbar.json`
- `BetterTouchTool` consume ese payload via widgets de shell script
- las acciones del widget leen el mismo payload para abrir `Resume`

Eso permite avanzar sin acoplar la app a AppleScript o UUIDs de widgets especificos.

## Fuente de usage implementada para la siguiente iteracion

La app ahora intenta una fuente exacta separada del parser de filesystem. La prioridad actual es:

1. leer una captura local de `rate_limits` generada por un script de `statusline`
2. intentar `claude -p "/usage"` como sonda experimental
3. degradar a porcentajes estimados por politica cuando ninguna fuente exacta es valida

Esto mantiene el adaptador de usage aislado del parser de filesystem y evita mezclar telemetria observada con cuota exacta.

### Motivacion

- usa una superficie oficial reciente de Claude Code para `rate_limits`
- evita seguir adivinando el porcentaje desde tokens acumulados
- mantiene a `claudeBar` desacoplado de una UI visual o scraping de pantalla

### Limitacion conocida

En esta maquina, con `Claude Code 2.1.108` del 15 de abril de 2026, `claude -p "/usage"` devuelve `Unknown command: /usage`. Por eso la ruta mas confiable hoy pasa por `rate_limits` en status line y no por ese slash command en modo `-p`.

### Implicacion de diseño

La capa de aplicacion debe poder combinar dos fuentes distintas:

- `filesystem telemetry` para sesion, tareas y pasos recientes
- `exact usage providers` para cuota y porcentajes

Por eso la implementacion no incrusta esta logica dentro de `ClaudeFilesystemActivityRepository`; se modela como un puerto separado y se fusiona en el caso de uso.

## Extension natural

Si la idea valida, el siguiente corte tecnico es extraer un `ClaudeBarAgent` local que entregue un contrato estable a la UI y permita integrar:

- una fuente mas exacta de cuotas basada en `claude -p "/usage"`
- una estrategia persistente para Touch Bar via bridge externo
- pruebas de integracion independientes de AppKit
