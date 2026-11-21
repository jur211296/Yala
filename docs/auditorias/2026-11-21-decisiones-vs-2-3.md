# Decisiones de Jürgen contra el código de 2.3 (21-nov-2026)

**Artifact con el detalle, la evidencia y el selector sí/no/después por propuesta:**
https://claude.ai/artifact/VfRj9Xg1ufZP8uZpPaD972

## Por qué

La decisión del 20-nov sobre la fila de Favoritos de Nuevo registro figuraba como «incorporada» en el registro de
decisiones y nunca llegó a un encargo ni al código. «Incorporada» significa que se escribió en la documentación, no que
esté implementada. Esta auditoría busca cada decisión en el código y en los PRs mergeados.

## Alcance y método

- Fuente: registro de decisiones de la flota (`~/Claude/flota/decisiones/decisiones.jsonl` en la Mini), proyecto Yala,
  tipo `capturada`, con las sustituciones aplicadas (manda la más nueva). **El registro empieza el 7-nov**: lo que
  Jürgen decidió del 1 al 7-nov no está en él.
- 174 decisiones vigentes, del 8 al 21-nov. 55 no piden cambio (proceso de la flota, releases, «se deja como está»).
- Las otras 119 se buscaron en `origin/2.3` en d556c57a8: archivo y línea, o PR mergeado. «En encargo» solo cuenta
  las sesiones vivas o en cola del coordinador el 21-nov a las 06:20.
- Medido en el código, sin capturas del simulador.

## Resultado

| Estado | Cuántas |
|---|---|
| Implementada en 2.3 | 88 |
| Parcial | 10 |
| En encargo (sesión viva o en cola) | 6 |
| Sin encargo | 4 |
| Fuera del repo (consolas de Dan) | 10 |
| Pospuesta a propósito | 1 |
| No pide cambio | 55 |

## Lo que falta y nadie hace: encargos propuestos (sin encolar)

| Prioridad | Encargo propuesto | Vista | Decisiones |
|---|---|---|---|
| Alta | Confirmar con Dan lo que falta en las consolas (CloudKit Production del Flujo de caja y del logo propio, migración y Worker v8, Sentry) | Consolas | 170, 143, 136, 15, 172 |
| Alta | Navegadores conectados en la app publicada (hoy solo en Yala Dev) | Ajustes | 42, 51 |
| Alta | Encender Yala IA ampliada en producción (sigue al 0 %) y llevar el conector a mcp.yala-app.pe | Servidor | 14, 64 |
| Alta | El congelamiento tras guardar con la nube (YALA-IOS-A) | Sincronización | 145 |
| Alta | Novedades 2.3 completas y anuncio del iPhone Duo | Novedades | 118 |
| Media | Panel: llegada solo con Primeros pasos, y uso de línea de la tarjeta | Panel | 137, 117 |
| Media | Nota de salud, lote 2: lo que te queda del mes | Salud financiera | 30 |
| Media | Atajo del banco y suscripciones, segunda parte (B2, B3, S2) | Lo que Yala apunta solo | 66 |
| Media | Captura con foto: la IA reconoce el comercio | Captura | 75 |
| Media | Política y términos sin «Conectar Gmail» (hotfix sobre 1.0) | Web pública | 122 |
| Baja | Guiado de pago planificado: «¿es un gasto compartido?» | Yala IA | 85 |
| Baja | Yala web dentro de Claude | Conector | 21 |

## En encargo

- Fila de Favoritos (168): sesión viva «favoritos-fila-ver-todos-arriba-chips-completos».
- «Ajusta el límite a lo real» y el límite propuesto en el editor (174, 162): encargo en cola
  «salud-ajusta-limite-editor-prellenado».
- Reglas de cuenta, capa de la IA en el chat y nombres de cuentas con iCloud (155, 161, 173): encargo en cola
  «cuenta-sola-al-leer-parte-2-reglas».
