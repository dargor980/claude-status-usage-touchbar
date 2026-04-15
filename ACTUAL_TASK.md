# ACTUAL_TASK

## Tarea activa

**Fase 3: integrar una fuente mas exacta de usage para `claudeBar`**

La fase 2 ya dejo resuelta la estrategia de Touch Bar persistente. El siguiente gap del MVP es la precision del porcentaje:

> mostrar el uso real de Claude con menos inferencia local y mas datos oficiales del propio Claude Code.

## Objetivo de esta tarea

Integrar una fuente exacta o casi exacta de usage sin romper el contrato del snapshot ni degradar la app cuando esa fuente no este disponible.

## Alcance

- ejecutar una consulta headless o equivalente para obtener `rate_limits`
- parsear porcentaje de sesion, porcentaje semanal y resets
- preferir esa fuente cuando sea valida
- mantener fallback a `estimated` cuando falle o no exista

## Fuera de alcance

- eliminar por completo el fallback estimado
- empaquetar la app como `.app`
- soporte multi-sesión
- cobertura de tests de fixtures reales

## Criterios de cierre

- existe una fuente exacta integrada o una ruta soportada equivalente
- la UI distingue entre exacto y estimado
- queda registrado el fallback cuando no hay source exacta
- la implementación y el contrato quedan reflejados en documentación

## Estado actual

- `Fase 1` funcional: completada
- `Fase 2` Touch Bar persistente: completada a nivel de decision tecnica
- `Fase 3` usage exacto: en implementacion
- hallazgo actual: en `Claude Code 2.1.108` del 15 de abril de 2026, `claude -p "/usage"` devuelve `Unknown command: /usage` en este entorno
- ruta soportada actual: `rate_limits` expuesto a scripts de status line y fallback estimado si no hay captura disponible
