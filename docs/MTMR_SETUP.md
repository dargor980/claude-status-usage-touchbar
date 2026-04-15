# MTMR setup para claudeBar

## Que es MTMR

[My TouchBar My Rules](https://github.com/Toxblh/MTMR) es una app open source y gratuita
que reemplaza la Touch Bar del sistema con una configuracion basada en JSON.
A diferencia de la Touch Bar de AppKit, los widgets de MTMR persisten sin importar
que app este al frente.

## Instalacion rapida

```bash
# 1. Instalar MTMR
brew install --cask mtmr

# 2. Generar el snippet de configuracion con las rutas de este repositorio
python3 scripts/claudebar_mtmr_generate_config.py
```

El generador crea:
- `claudebar-mtmr.json` — snippet de items para pegar en MTMR
- `scripts/claudebar_mtmr_title.sh` — wrapper del widget de titulo
- `scripts/claudebar_mtmr_task.sh` — wrapper del widget de tarea
- `scripts/claudebar_mtmr_resume.sh` — wrapper de la accion resume

## Configurar MTMR

1. Abrir MTMR (aparece en la barra de menu).
2. Click derecho en el icono → **Preferences** → editor JSON.
3. Pegar el contenido de `claudebar-mtmr.json` junto a los items existentes.

Ejemplo de `items.json` completo minimo:

```json
[
  { "type": "escape", "width": 32 },
  {
    "type": "shellScriptTitledButton",
    "source": { "filePath": "/ruta/scripts/claudebar_mtmr_title.sh" },
    "refreshInterval": 2,
    "align": "left",
    "width": 220,
    "bordered": false,
    "action": { "type": "shellScript", "filePath": "/ruta/scripts/claudebar_mtmr_resume.sh" }
  },
  {
    "type": "shellScriptTitledButton",
    "source": { "filePath": "/ruta/scripts/claudebar_mtmr_task.sh" },
    "refreshInterval": 2,
    "align": "left",
    "width": 200,
    "bordered": false
  }
]
```

4. Click **Touch it!** para aplicar.
5. macOS puede pedir permisos de Accessibility la primera vez.

## Como funciona

```
claudeBar (ejecutandose como login item)
    ↓  escribe cada 2s
~/.claude/claudebar-touchbar.json   (bridge file)
    ↑  lee cada 2s
MTMR (shellScriptTitledButton)
    ↓  muestra
Touch Bar (persistente, cualquier app al frente)
```

No se requiere BetterTouchTool ni ninguna otra herramienta de pago.

## Diferencias con BetterTouchTool

| | BTT | MTMR |
|---|---|---|
| Precio | Pago (trial 45 dias) | Gratuito / open source |
| Push updates | Si (via JXA) | No (solo polling) |
| Polling interval | configurable | configurable |
| Instalacion | Manual o `brew install --cask bettertouchtool` | `brew install --cask mtmr` |
| Config | GUI + preset JSON | Solo JSON |

Con claudeBar, el polling de 2 segundos es suficiente — la diferencia de latencia
respecto al push de BTT es imperceptible.

## Notas

- Si MTMR no esta activo, la Touch Bar vuelve a mostrar el comportamiento del sistema.
- El bridge file persiste aunque claudeBar no este corriendo; MTMR seguira
  mostrando el ultimo estado conocido.
- Para ajustar el ancho de los widgets editá los campos `width` en el JSON.
