# Barrido de QA de la 2.3 antes de la build 9 (25-nov-2026)

Base: `origin/2.3` en el merge de «la fila con fuentes de la Bandeja» (lote 3), más el lote 4 de la Bandeja (casar con
planificados) cuando entró. Lista base: el barrido de la build 8 (`docs/qa/barrido-2-3-antes-build-8/`) y los cuerpos
de los PR mergeados desde «chore(release): Yala 2.3 (8)».

Evidencia: `~/Claude/entregas/2026-11-25-barrido-y-testflight-2-3-build-9/evidencia/` (`iphone14/`).

## Cómo se probó

- **iPhone 14 real** (iOS 27.2.1, Mini, Device MCP). Yala Dev en `Debug-Dev`, con los ganchos de pruebas
  (`-uitest`, semilla `minimal` y las semillas de la Bandeja `-uitest-inbox-joined-draft`,
  `-uitest-inbox-same-expense-pair`, `-uitest-inbox-duplicate-draft`; Correo del banco con `-uitest-bank-email` y
  el enlace de Gmail en la tercera búsqueda).
- El almacén de pruebas del teléfono vive en el App Group y traía la semilla pesada de otra sesión (diez años, varias
  «Cuenta Principal»): `-uitest-reset` no cabe en los 20 s del arranque y iOS mata la app. Se probó sin reset, sobre
  esos datos. Es solo del gancho de pruebas.
- **Simulador iPhone 17 Pro**: las pruebas de interfaz de lo nuevo (ver abajo).

## Lo nuevo desde la build 8

| Qué | Resultado | Evidencia |
|---|---|---|
| Bandeja: «¿Es el mismo gasto?» (Rappi por Apple Pay ayer 23:50 y el correo hoy con otro importe) | Bien. Tarjeta con las dos filas, sus fuentes y «Es el mismo» / «Son distintos» | `01-…` |
| «Es el mismo» | Bien. Queda un Rappi con el importe del banco (S/ 92.40), la fecha de Apple Pay («Ayer») y las cápsulas «Apple Pay · Correo»; 9 → 8 pendientes | `06-…` |
| Fila con fuentes (Starbucks unido al llegar) | Bien. «Apple Pay · Correo» en la fila | `03-…` |
| Borrador unido y «Separar» | Bien. «Juntamos el mismo gasto: Apple Pay · Correo» con «Separar»; al separar vuelven dos pendientes (8 → 9) y no se vuelven a preguntar | `04-…`, `05-…` |
| «Ya registrado el 25 nov» con «Descartar» / «Guardar igual» | Bien a tamaño normal | `02-…` |
| Aviso de posible duplicado que nombra el gemelo | Bien: «Ya hay uno parecido: Almuerzo equipo · S/ 42.50 · 25 nov. ¿Guardarlo de todas formas?» | `07-…` |
| Correo del banco › Gmail, paso 3 | Bien. «Confirma tu dirección de Yala en Gmail», busca solo, «Todavía no ha llegado. Nueva búsqueda en 9 s.» y, al llegar el enlace, «Confirmar en Google» | `08-…`, `09-…` |
| Avisos del banco: guía de Atajos de iOS 27 (arreglo del barrido 8) | Bien: «+» abajo al centro, pestaña «Automatización», buscador de la hoja, «‹» para guardar | `13-…` |
| Panel: «Ver detalle ›» (arreglo del barrido 8) | Bien: abre Estadísticas. En VoiceOver va como acción del hero, a propósito | — |
| Conector de IA (ver la Bandeja, referencia, posible duplicado) | Solo servidor: no viaja en la build. Sin producción todavía (runbook del conector, «Lote 5») | — |

## Cifras que tienen que coincidir

| Comprobación | Resultado |
|---|---|
| Panel «Tu saldo hoy» = curva de Saldo = Flujo de caja «Tienes hoy» | S/ 405,372.94 en las tres |
| Panel = widget «Saldo» de inicio (Todo el tiempo) | S/ 405,372.94 y S/ 405,373 (el widget redondea) |

## Pase de estrés (lo nuevo de la Bandeja)

- **Claro**: bien (`12-…`). **Oscuro**: el resto del recorrido.
- **Texto al máximo (AX5)**: la Bandeja abre y se desplaza; las cápsulas de fuente caben. «Ya registrado» parte
  «Des-cartar» por sílabas (nuevo) → `tickets/backlog/2026-11-25-ya-registrado-parte-descartar-con-texto-grande.md`.
  «Pendien-tes», «Cate-goría» y «STAR-BUCKS» ya se partían en la build 8.
- **Girado**: el iPhone tiene el bloqueo de rotación puesto (ajuste de Jürgen, no se toca).

## Hallazgos

1. **BLOQUEA LA SUBIDA: el esquema de iCloud de Producción no tiene el campo nuevo de la Bandeja.** La build escribe
   `CD_InboxDraft.CD_joinRecordRaw` (lo que la Bandeja unió al llegar, lote 2) y Producción no lo tiene (medido con
   `cktool export-schema --environment production` el 25-nov a las 03:34; el límite de la tarjeta, el otro campo
   pendiente de la semana, sí está). El repo lo lista en `pendingProductionDeploy` y `scripts/asc-preflight.sh` frena la
   subida por eso: en TestFlight, el primer borrador unido no sincronizaría y la cuenta dejaría de sincronizar con
   iCloud sin aviso. Desplegarlo es de Dan con el OK de Jürgen.
2. Texto al máximo: «Des-cartar» en «Ya registrado» (arriba). Backlog.
