# BetterTouchTool setup para claudeBar

## Objetivo

Mostrar `claudeBar` en la Touch Bar real del Mac aunque otra app tenga el foco.

La estrategia es:

1. `claudeBar` escribe `~/.claude/claudebar-touchbar.json`
2. `BetterTouchTool` renderiza widgets de Touch Bar leyendo ese archivo
3. un tap en el widget puede abrir el `remoteURL` de la sesion actual

## Prerrequisitos

- `claudeBar` compilado y ejecutandose
- `BetterTouchTool` instalado y con Touch Bar personalizada activa

## Archivos relevantes

- payload del bridge: `~/.claude/claudebar-touchbar.json`
- widget principal: [scripts/claudebar_btt_widget.py](/Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_btt_widget.py:1)
- accion resume: [scripts/claudebar_btt_action.py](/Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_btt_action.py:1)

## Widget principal

En `BetterTouchTool`, crear un widget de Touch Bar tipo shell script y configurarlo asi:

- script:

```bash
/usr/bin/python3 /Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_btt_widget.py title
```

- refresh interval: `2` segundos
- width sugerido: `220` a `320`
- nombre visual sugerido: `claudeBar`

Salida esperada:

`claudeBar 5h 42% · 7d 61%`

## Widget de tarea

Agregar un segundo widget opcional:

```bash
/usr/bin/python3 /Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_btt_widget.py task
```

Salida esperada:

`repo · Implementar bridge BTT`

## Acción de tap para Resume

Al widget principal se le puede asociar una accion de shell script:

```bash
/usr/bin/python3 /Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_btt_action.py resume
```

Si la sesion tiene `remoteURL`, abre Claude Code en esa sesion. Si no existe, la accion falla de forma explicita.

## Variables opcionales

- `CLAUDEBAR_TOUCHBAR_BRIDGE_PATH`
  - override del JSON de bridge si no quieres usar `~/.claude/claudebar-touchbar.json`
- `CLAUDEBAR_APP_PATH`
  - se usa solo si quieres que una accion secundaria abra la app con `claudebar_btt_action.py dashboard`

## Modo de arranque recomendado

Ejecutar `claudeBar` sin dashboard visible:

```bash
open /Users/germancontreras/claude-status-usage-touchbar/.build/scratch/arm64-apple-macosx/debug/claudebar
```

Si quieres volver a levantar el panel espejo al iniciar:

```bash
CLAUDEBAR_OPEN_DASHBOARD_ON_LAUNCH=1 open /Users/germancontreras/claude-status-usage-touchbar/.build/scratch/arm64-apple-macosx/debug/claudebar
```

## Notas

- este bridge no reemplaza la Touch Bar publica de `AppKit`; la evita
- si `claudeBar` no corre, `BetterTouchTool` seguira mostrando el ultimo payload persistido
- si no hay sesion activa, el widget sigue mostrando porcentajes y estado degradado
