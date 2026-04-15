# Historias tecnicas por fases

## Fase 1. Base funcional

Objetivo: validar que el usuario perciba el estado de Claude sin abrir manualmente `/usage`.

Historias:

1. Como usuario quiero ver la sesion reciente para saber si claudeBar esta leyendo la fuente correcta.
2. Como usuario quiero ver una barra de sesion para entender cuanto he consumido del presupuesto configurado.
3. Como usuario quiero ver una barra semanal para tener contexto de uso acumulado.
4. Como usuario quiero ver la tarea activa o la ultima finalizada para entender en que va Claude.
5. Como usuario quiero un panel espejo para depurar el MVP cuando la Touch Bar no este visible.

## Fase 2. Experiencia Touch Bar real

Objetivo: acercar el comportamiento al requisito de “visible mientras VS Code esta al frente”.

Historias:

1. Evaluar integracion con Touch Bar persistente sin depender de foco de ventana. Estado: resuelto. `AppKit` publico queda como fallback, no como solucion persistente.
2. Comparar tres rutas: API privada experimental, companion app con automatizacion, o integracion con herramienta de terceros. Estado: resuelto. Se recomienda herramienta de terceros con bridge; API privada descartada; companion postergado como patron interno.
3. Mantener el contrato del dominio estable para no tocar la UI al cambiar la estrategia. Estado: en curso. La UI interna conserva `ClaudeBarSnapshot` y la estrategia Touch Bar se modela por separado.

## Fase 3. Precisión de uso

Objetivo: acercar el porcentaje a la realidad de Claude.

Historias:

1. Ejecutar `claude -p "/usage"` desde `claudeBar` en modo headless para consultar la cuota actual.
2. Capturar y parsear `stdout` con `Regex` para extraer porcentaje de sesion, porcentaje semanal y resets.
3. Reemplazar la politica de presupuestos por la salida de la CLI cuando el parseo sea valido.
4. Registrar fallback a `estimated` cuando la CLI falle o cambie de formato.

## Fase 4. Producto utilizable

Objetivo: pasar de prototipo a utilidad diaria.

Historias:

1. Empaquetar como `.app`.
2. Agregar lanzamiento al iniciar sesion.
3. Añadir tests de parser para fixtures reales de `~/.claude`.
4. Añadir logs y diagnostico para sesiones no detectadas.
5. Soportar multiples sesiones y seleccion manual.
