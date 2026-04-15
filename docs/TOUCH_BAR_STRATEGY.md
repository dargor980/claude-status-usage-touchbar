# Estrategia Touch Bar persistente

## Problema

La integracion actual con `NSTouchBar` sirve para validar el producto, pero no cumple el caso principal:

> ver el estado de Claude mientras una app como VS Code esta al frente.

Con API publica de `AppKit`, `claudeBar` puede proveer su propia Touch Bar, pero no aduenarse de una barra persistente cuando otra app es la activa.

## Opciones evaluadas

| Ruta | Persistencia | Riesgo | Mantenibilidad | Decision |
| --- | --- | --- | --- | --- |
| API privada experimental | Alta | Alta | Baja | Descartada |
| Companion app con automatizacion | Parcial | Media | Media | Postergada |
| Herramienta de terceros con bridge | Alta | Media | Media | Recomendada |

### 1. API privada experimental

Pros:

- podria acercarse mas a una barra realmente global
- evita depender de software adicional

Contras:

- requiere frameworks no publicos y comportamiento fragil entre versiones de macOS
- complica firma, distribucion y soporte
- deja al producto atado a una superficie tecnica no soportada por Apple

Decision:

- no avanzar con esta ruta salvo que falle todo lo demas

### 2. Companion app con automatizacion

Pros:

- mantiene control del payload y de las acciones en una capa propia
- sirve como base para un bridge desacoplado del renderer final

Contras:

- por si sola no resuelve la persistencia si el render sigue viviendo en la Touch Bar publica de `AppKit`
- termina necesitando igual una tecnologia adicional que ya controle la barra o algun workaround de bajo nivel

Decision:

- mantener esta opcion como patron de integracion interna, no como destino final del render

### 3. Herramienta de terceros con bridge

Pros:

- resuelve el problema principal mas rapido: Touch Bar visible mientras otra app tiene el foco
- reduce riesgo de plataforma porque el renderer persistente ya existe
- deja a `claudeBar` centrado en telemetria, acciones y contrato de datos

Contras:

- introduce dependencia externa
- agrega trabajo de onboarding y soporte para configuracion del usuario

Decision:

- estrategia elegida para el siguiente corte
- objetivo inicial: `BetterTouchTool`
- alternativa secundaria: `MTMR`

## Decision tecnica

La siguiente implementacion debe tratar a `claudeBar` como **proveedor de estado** y no como **owner unico de la Touch Bar**.

La barra actual basada en `AppKit` queda como:

- fallback interno
- modo espejo para depuracion
- referencia visual para validar el payload

La version persistente debe salir por un bridge externo que consuma un contrato estable.

## Implicaciones de arquitectura

1. `ClaudeBarSnapshot` se mantiene intacto.
2. La evaluacion de estrategia Touch Bar vive fuera del dominio.
3. El bridge externo consume un payload derivado de la misma fuente de verdad que usa la UI interna.
4. Cambiar de host persistente no debe obligar a reescribir vistas ni parsers.

## Siguiente corte de implementacion

1. Definir un payload local estable con:
   - sesion actual
   - gauges de uso
   - titulo de tarea
   - CTA para `Resume`
2. Publicar ese payload en un punto facil de leer por widgets o scripts locales.
3. Construir una prueba inicial con `BetterTouchTool`:
   - widget de texto o shell script
   - refresco periodico corto
   - accion para abrir el `remoteURL`
4. Mantener la Touch Bar publica actual como fallback mientras el bridge madura.

## Criterio de exito del siguiente corte

- la informacion de `claudeBar` sigue visible mientras VS Code esta al frente
- `Resume` funciona desde el host persistente elegido
- la app principal sigue operando aunque el bridge externo no este disponible
