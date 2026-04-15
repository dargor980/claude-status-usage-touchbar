# BetterTouchTool setup para claudeBar

## Objetivo

Mostrar `claudeBar` en la Touch Bar real del Mac aunque otra app tenga el foco.

La estrategia es:

1. `claudeBar` escribe `~/.claude/claudebar-touchbar.json`
2. `BetterTouchTool` puede renderizar widgets via polling de shell script o recibir updates directos por UUID
3. un tap en el widget puede abrir el `remoteURL` de la sesion actual

## Prerrequisitos

- `claudeBar` compilado y ejecutandose
- `BetterTouchTool` instalado y con Touch Bar personalizada activa

## Setup rapido con preset (recomendado)

El preset genera los widgets con los UUIDs canonicos que `claudeBar` usa por defecto.
No se requiere configurar env vars.

```bash
# 1. Generar el preset con las rutas de este repositorio
python3 scripts/claudebar_btt_generate_preset.py

# 2. Importar en BetterTouchTool
#    Preferences → Presets → Import Preset → seleccionar claudebar.bttpreset

# 3. Iniciar claudeBar como login item (opcional)
bash scripts/claudebar_install.sh

# 4. O simplemente ejecutar:
.build/scratch/arm64-apple-macosx/debug/claudebar
```

Los dos widgets aparecen en la Touch Bar inmediatamente.  
`claudeBar` empuja actualizaciones directas a los widgets en cada refresh.

## Archivos relevantes

- payload del bridge: `~/.claude/claudebar-touchbar.json`
- widget principal: [scripts/claudebar_btt_widget.py](/Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_btt_widget.py:1)
- accion resume: [scripts/claudebar_btt_action.py](/Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_btt_action.py:1)
- generador de preset: [scripts/claudebar_btt_generate_preset.py](/Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_btt_generate_preset.py:1)
- instalador de login item: [scripts/claudebar_install.sh](/Users/germancontreras/claude-status-usage-touchbar/scripts/claudebar_install.sh:1)

## Widget principal (setup manual)

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

## Modo recomendado: update directo por UUID

Si quieres evitar depender del `refresh interval`, puedes dejar el widget como shell script para el primer render y ademas permitir que `claudeBar` lo actualice en cada refresh.

Pasos:

1. Crear el widget principal como en la seccion anterior.
2. En BetterTouchTool, hacer click derecho sobre el widget y copiar su UUID.
3. Lanzar `claudeBar` con `CLAUDEBAR_BTT_TITLE_WIDGET_UUID` y, si tienes segundo widget, tambien `CLAUDEBAR_BTT_TASK_WIDGET_UUID`.

Ejemplo:

```bash
CLAUDEBAR_BTT_TITLE_WIDGET_UUID="UUID-DEL-WIDGET-PRINCIPAL" \
CLAUDEBAR_BTT_TASK_WIDGET_UUID="UUID-DEL-WIDGET-TAREA" \
/Users/germancontreras/claude-status-usage-touchbar/.build/scratch/arm64-apple-macosx/debug/claudebar
```

Notas:

- este modo usa el bridge oficial de scripting de BetterTouchTool para `update_touch_bar_widget`
- el shell script sigue siendo util como primer render y fallback si BetterTouchTool reinicia
- macOS puede pedir permiso de Automation la primera vez que `claudeBar` intente hablar con BetterTouchTool

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
- `CLAUDEBAR_BTT_TITLE_WIDGET_UUID`
  - UUID del widget principal para updates directos desde `claudeBar`
- `CLAUDEBAR_BTT_TASK_WIDGET_UUID`
  - UUID del widget secundario de tarea para updates directos desde `claudeBar`
- `CLAUDEBAR_APP_PATH`
  - se usa solo si quieres que una accion secundaria abra la app con `claudebar_btt_action.py dashboard`

## Modo de arranque recomendado

Ejecutar `claudeBar` sin dashboard visible:

```bash
/Users/germancontreras/claude-status-usage-touchbar/.build/scratch/arm64-apple-macosx/debug/claudebar
```

Si quieres volver a levantar el panel espejo al iniciar:

```bash
CLAUDEBAR_OPEN_DASHBOARD_ON_LAUNCH=1 /Users/germancontreras/claude-status-usage-touchbar/.build/scratch/arm64-apple-macosx/debug/claudebar
```

## Notas

- este bridge no reemplaza la Touch Bar publica de `AppKit`; la evita
- si `claudeBar` no corre, `BetterTouchTool` seguira mostrando el ultimo payload persistido
- si no hay sesion activa, el widget sigue mostrando porcentajes y estado degradado
