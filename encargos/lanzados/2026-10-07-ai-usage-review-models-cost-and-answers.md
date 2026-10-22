# Revisar cómo usa Yala la IA hoy (modelos, coste y estructura de respuestas) y dejar un informe con oportunidades y tickets nuevos, sin cambiar modelo ni proveedor

## Contexto
Card del tablero `tablero-revisar-el-uso-de-ia-modelos-coste-y-res-v6or` (lista para lanzar, prioridad media). Jürgen la pidió el 2026-10-03: es trabajo pensado para la versión 2.2 y no entra en el lanzamiento de 2.1, pero es una investigación, no una implementación. El resultado es un documento y tickets en el repo; no cambia el comportamiento de la app.

Jürgen quiere saber:
- Qué modelos y proveedores usa Yala hoy y en qué funciones (Yala AI, registro por voz, registro por imagen, categorización, resúmenes o lo que haya), con qué parámetros y desde dónde se llaman (app, funciones en la nube, lo que sea).
- Qué dice la documentación más reciente de esos modelos: versiones nuevas, precios, límites, salida estructurada, buenas prácticas de prompts.
- Si somos eficientes: tokens por llamada, contexto que se manda de más, llamadas repetidas, caché, reintentos, modelo más caro de lo necesario para la tarea.
- Si el modelo actual es el mejor posible sin gastar de más, y qué alternativas hay (otros modelos del mismo proveedor y de otros), con pros, contras y coste estimado.
- Si las respuestas están bien esquematizadas y estructuradas (formato, esquemas JSON, validación, manejo de errores, idioma).

Hoy se cerró el PR #384 (los tres tests de la suite UI que fallaban siempre), en cola de auto-merge a 2.1. No depende de este encargo.

Para orientarte: `CLAUDE.md`, `STATE.md`, `.claude/rules/` que toquen, y `grep` del código por los clientes de IA. No leas el repo entero.

## Que se pide
1. Inventario del uso de IA actual con rutas de código concretas.
2. Revisión contra la documentación oficial actual de cada proveedor (cítala con enlace y fecha de consulta). No inventes precios ni cifras: si no puedes confirmar un dato, dilo.
3. Informe en `docs/` del repo (por ejemplo `docs/ai-usage-review-2026-10.md`) con hallazgos, oportunidades ordenadas por impacto y una tabla de alternativas.
4. Tickets nuevos en `tickets/` del repo, separados en dos grupos y así marcados:
   - Autónomos: bugs y mejoras acotadas de prompts o de estructura de respuesta que se pueden lanzar sin Jürgen.
   - Para Jürgen: cualquier cambio de modelo, de proveedor o de coste relevante, con opciones A/B/C y recomendación.
5. Si sale algo que toca a la card `tablero-partir-la-ia-segun-modo-nube-o-privado-0y9k` (partir la IA según modo nube o privado, 2.2), anótalo en el informe como insumo para esa sesión, sin implementarlo.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, solo docs y tickets, limpieza). Al cerrar, mueve la card `tablero-revisar-el-uso-de-ia-modelos-coste-y-res-v6or` a «in qa» asignada a `jurgen` (tiene que leer el informe y decidir) con `tablero mover <id> --a "in qa" --agente frank` y `tablero asignar <id> --a jurgen --agente frank`.

## Que NO hay que tocar
- Ni código de la app ni de las funciones en la nube: nada de cambiar modelo, proveedor, prompts ni parámetros en este encargo. Solo documentos y tickets.
- Nada de producción ni de staging; no hagas llamadas de pago a las APIs de IA para medir.
- No hace falta build ni simulador: no compiles ni arranques ningún simulador. Si por algún motivo lo necesitaras, sigue el pipeline serial de la Mini (limpiar, build con `-jobs 2` sin simulador, un solo simulador, tests, apagar y borrar ese simulador) y borra al cerrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar.
- No crees secretos en el Llavero. No toques `marketing/` (es de Lola).

## Como se sabe que esta bien
- Existe el informe en `docs/` con inventario, revisión documentada con fuentes, oportunidades y alternativas.
- Hay tickets nuevos en `tickets/`, cada uno marcado como autónomo o para Jürgen.
- El PR a 2.1 solo trae documentos y tickets, está en auto-merge, y la card quedó en «in qa» asignada a jurgen.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Nadie estaba delante: cada nodo lo contesté yo y seguí. Se discute en el PR.

| # | Decisión | Qué elegí | Por qué |
|---|---|---|---|
| D1 | ¿Cómo mido tokens por llamada sin llamadas de pago? | **Estimación desde el código** (longitud de prompts y topes de los arrays del contexto), marcada como estimación | El encargo prohíbe llamar a la API para medir. El gateway no registra `usage`, así que no hay dato real que leer: eso pasa a ser un ticket |
| D2 | ¿Qué cuenta como «autónomo»? | Bugs y mejoras de prompt o de forma de respuesta que **no cambian modelo, proveedor ni el coste de forma relevante**: idioma, errores, `json_schema` estricto, tope de salida, caché | Es la frontera que fija la card y el encargo |
| D3 | ¿Reducir la imagen antes de mandarla o pasar a `detail: low`? | **Para Jürgen** | Cambia el coste y puede cambiar la calidad de lectura de un recibo largo: es una decisión de producto con opciones |
| D4 | ¿Mover la elección de modelo al gateway? | **Para Jürgen** | Es arquitectura y permite cambiar modelo sin release; toca el contrato cliente-gateway |
| D5 | ¿Formato del informe? | Markdown en `docs/ai-usage-review-2026-10.md` | Lo pide el encargo; vive en el repo junto a los tickets |
| D6 | Duplicados | `gateway-has-no-telemetry` cubre el gateway sin telemetría en general; el ticket de tokens de IA se escribe aparte y lo enlaza | Es un caso concreto con su propio criterio de hecho |
