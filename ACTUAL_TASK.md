# ACTUAL_TASK

## Tarea activa

**Fase 2: validar una estrategia de Touch Bar persistente para `claudeBar`**

El MVP base ya existe: la app compila, lee telemetría local de `~/.claude`, calcula barras de uso estimadas y muestra la sesión/tarea en una ventana nativa más una integración de Touch Bar con API pública de `AppKit`.

El mayor gap entre el MVP actual y la propuesta de valor del producto sigue siendo este:

> mostrar el estado de Claude mientras otra app como VS Code está al frente.

## Objetivo de esta tarea

Definir y probar una estrategia técnica realista para que la información de `claudeBar` sea visible en la Touch Bar sin depender de que `claudeBar` sea la app enfocada.

## Alcance

- investigar alternativas viables en macOS para Touch Bar persistente
- comparar costo, riesgo y mantenibilidad de cada enfoque
- elegir una estrategia principal para la siguiente implementación
- documentar la decisión y el plan de ejecución

## Opciones a evaluar

1. API privada o integración no pública de Touch Bar
2. companion app con automatización o bridging adicional
3. integración con herramienta de terceros que ya controle la Touch Bar

## Fuera de alcance

- implementar todavía la consulta exacta de `/usage`
- empaquetar la app como `.app`
- soporte multi-sesión
- cobertura de tests de fixtures reales

## Criterios de cierre

- existe una recomendación técnica clara
- la recomendación incluye tradeoffs y riesgos
- queda definido el siguiente corte de implementación
- la decisión queda reflejada en `docs/ARCHITECTURE.md` y/o `docs/ROADMAP.md`

## Estado actual

- `Fase 1` funcional: completada
- `Fase 2` Touch Bar persistente: en análisis
- bloqueo principal: `AppKit` público no garantiza una barra persistente cuando otra app tiene el foco
- spec aprobada para `usage` futuro: ejecutar `claude -p "/usage"` en modo headless, capturar stdout y parsearlo con Regex
