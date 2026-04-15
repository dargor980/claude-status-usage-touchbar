# ACTUAL_TASK

## Tarea activa

**Fase 2.1: bridge real a BetterTouchTool para Touch Bar persistente**

La estrategia de fase 2 ya quedo decidida: `claudeBar` no debe intentar dominar la Touch Bar por `AppKit` publico cuando otra app tiene el foco. El siguiente paso operativo es convertir esa decision en una integracion real.

> mostrar el estado de Claude en la Touch Bar del Mac mientras Terminal, VS Code o Cursor estan al frente.

## Objetivo de esta tarea

Implementar un bridge utilizable con `BetterTouchTool`, manteniendo a `claudeBar` como proveedor de estado y dejando la ventana dashboard como herramienta de debug opcional.

## Alcance

- generar un payload estable para Touch Bar externa
- escribir ese payload desde la app en cada refresh
- incluir scripts listos para widgets y acciones en `BetterTouchTool`
- documentar el setup minimo para que la Touch Bar realmente muestre `claudeBar`

## Fuera de alcance

- soporte MTMR completo
- empaquetar la app como `.app`
- soporte multi-sesión
- perfeccionar mas la precision de usage si eso retrasa el bridge

## Criterios de cierre

- la app puede correr sin abrir el dashboard por defecto
- existe un archivo de bridge estable para host externo
- el repo incluye scripts de widget y accion para BetterTouchTool
- la documentacion deja claro como verlo en la Touch Bar real

## Estado actual

- `Fase 1` funcional: completada
- `Fase 2` Touch Bar persistente: completada a nivel de decision tecnica
- `Fase 2.1` bridge BetterTouchTool: completada
- bridge por archivo: implementado
- scripts de widget y accion para BetterTouchTool: implementados
- update directo opcional por UUID de widget: implementado
- `Fase 2.2` simplificacion de setup: completada
- preset `.bttpreset` generado por script con UUIDs canonicos: implementado
- `claudeBar` usa UUIDs canonicos por defecto sin env vars: implementado
- login item via launchd (`claudebar_install.sh`): implementado
- `Fase 3` usage exacto: postergada
- limitacion actual: la Touch Bar publica de `AppKit` solo aparece cuando `claudeBar` es la app enfocada
- ruta elegida: `BetterTouchTool` leyendo un payload local generado por `claudeBar`
- `Fase 2.3` packaging como `.app`: completada
- `build-app-bundle.sh` incluye scripts Python, preset, `LSUIElement` y `NSAppleEventsUsageDescription`
- `claudebar_install.sh` crea bundle + launchd agent en un paso
- siguiente corte: validacion manual del preset y flujo completo en BetterTouchTool real
