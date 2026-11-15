---
id: yala-web-lote-2b
status: done
priority: high
area: web
created: 2026-11-14
updated: 2026-11-14
source: encargo 2026-11-14-yala-web-lote-2b (Jürgen, 14-nov 13:52: «el resto del lote 2 como Frank recomiende»)
---
# Yala web, lo que faltó del lote 2: Presupuestos, ⌘K, CSV, «Ya pagado» y los 16 idiomas

Cierra el lote 2 del plan (`docs/web-app/index.html`). Parte del PR del lote 2 (sección «Qué quedó fuera») y va sobre
el lote 3 (Grupos), que comparte `webapp/`. Grupos en lectura no entra: lo hizo el lote 3. Solo staging.

## Alcance

1. **Presupuestos** en lectura, con las cifras de la pantalla del iPhone.
2. **Buscar en todo (⌘K)**.
3. **Exportar a CSV**.
4. **«Ya pagado»** en los próximos cobros.
5. **Los 16 idiomas de la app** en la web, sin los nombres de sitio que retiró la decisión 51 de 2.3.

## Paso 0 — decisiones

Medido antes de decidir (14-nov, sobre la rama del lote 3, en cola de auto-merge a 2.3):

- `shared-core` ya tiene `estado_presupuestos` (port de `BudgetsViewModel` + `InsightsCalculator.currentBudgetInterval`,
  con paridad en `mcp/test/golden.test.ts`). La web lo llama tal cual, como el Panel llama a `resumen_periodo`.
- El iPhone marca «pagado» así (`ScheduledPaymentsViewModel.calculatePaymentData` +
  `ScheduledPaymentPaidStatusHelper.loadPaidAmounts`): cuenta en el mes los movimientos enlazados al pago
  (`scheduledPaymentID`) y los borradores aprobados (`sourceScheduledPaymentID`), sin repetir pago y día, y da por
  pagadas las N primeras fechas del mes que no estén saltadas.
- Aprobar un borrador de un pago enlaza su movimiento al pago (`ScheduledPaymentDraftService`, línea 776), así que los
  movimientos enlazados cubren también lo aprobado.
- `inbox_drafts` no da `source_scheduled_payment_ref` al rol de la web (web1_01 solo abre las columnas de la Bandeja).
- `buscar_movimientos` pagina de 200 en 200. `RL_API` = 120 peticiones por minuto y sesión.
- La app tiene 16 catálogos: es, es-419, es-AR, es-ES, en, en-GB, de, fr, it, ja, nl, pl, pt, pt-BR, pt-PT, zh-Hans.
  es-419 = es y pt = pt-BR (0 líneas distintas); es-AR (voseo), es-ES y en-GB son variantes con cientos de diferencias.
- Los textos de la web en español decían «la nube de Yala» (dos sitios), un nombre retirado por la decisión 51.

Decisiones (tomadas por Frank: Jürgen lo dejó a su criterio):

1. **Presupuestos**: sección propia en la barra (sale de «Pronto»). Como el iPhone, en tres bloques: Excedidos, Activos e
   Inactivos, con gastado de límite, barra, lo que queda y los días que faltan. En lectura: crear y editar siguen en el
   iPhone.
2. **«Ya pagado»**: port de esa regla en el Worker (`webapp/src/worker/paid.ts`), con los movimientos enlazados. La fila
   lleva la marca «Ya pagado» y sale de «Por pagar». **Diferencia aceptada:** un borrador aprobado cuyo movimiento se
   borró después sigue contando en el iPhone y en la web no. Abrir esa columna pedía tocar la base de staging para un
   caso raro. Va en el Worker, no en `shared-core`, porque el encargo declara `toca:` solo `webapp/`.
3. **⌘K**: una paleta (⌘K o Ctrl+K, y una lupa en la barra de arriba para el móvil). Busca en las secciones, las cuentas,
   las categorías, los presupuestos y las notas de los registros. Elegir una cuenta o una categoría abre Registros con
   ese filtro; un registro abre su detalle.
4. **CSV**: botón «Exportar» en Registros, que exporta lo que se está viendo (período, cuenta, categoría y texto). La
   página pide los registros de 200 en 200 (tope 5.000, y lo dice si se corta) y arma el archivo en el navegador, con
   las cabeceras en el idioma de la página, UTF-8 con BOM (Excel abre bien las tildes) e importes con punto decimal.
   Sin ruta nueva en el Worker: `/api/registros` acepta `limite=200`.
5. **Idiomas**: un fichero por idioma (`src/client/i18n/<código>.ts`), con el tipo de los textos en español como
   contrato (si falta una clave, no compila). Las tres variantes (es-AR, es-ES y en-GB) son diferencias sobre su base,
   como en la app; es-419 y pt usan la base. El selector de Configurar ofrece los 16; sin elección, el del navegador
   (`navigator.languages`), y si no hay ninguno, español. Los términos se toman del catálogo de la app de cada idioma
   («Panel», «Bandeja»…). Un test repasa los 16 contra los nombres retirados de la decisión 51 (las mismas listas que
   `DosNombresDeSitioTests`), y «la nube de Yala» de la web pasa a «tu cuenta de Yala».
6. **Fechas e importes** con el `Intl` del idioma elegido (`es-PE` sigue para el español base, por «S/»).

## Resultado (14-nov, desplegado en staging)

- **Presupuestos**: `/api/presupuestos` y la sección en la barra (sale de «Pronto»), en tres bloques como el iPhone. El
  ojo tapa también el límite y lo que queda.
- **«Pagado»**: `src/worker/paid.ts` + `pagos` de `src/worker/data.ts`, con una sola lectura de los pagos. La marca usa la
  palabra de la app («Pagado», `scheduled.paid`). «Por pagar» se recalcula dando lo pagado por saltado, así redondea una
  sola vez. La revisión independiente no encontró fallos en la regla. Dos diferencias medidas y aceptadas: la del
  borrador aprobado (arriba) y el día de un movimiento guardado en otra zona justo al cambiar de mes (la web usa
  `local_day`, como en el resto de la web).
- **⌘K**: `src/client/app/Busqueda.tsx`, con la lupa en la barra. En el móvil sale arriba (abajo la taparía el teclado).
- **CSV**: `src/client/app/csv.ts`. El archivo es el del iPhone: cabeceras fijas en inglés (`date,amount,currency,…`),
  así vuelve a entrar por «Importar» y no hay que traducirlas.
- **16 idiomas**: un fichero por idioma en `src/client/i18n/`, traducidos con los términos del catálogo de cada idioma de
  la app. «Sin nombre» del núcleo sale en el idioma de la página. Configurar ofrece los 16.

Pruebas:

- `npm test`: 161 de 161 (nuevas: `test/lote2b.test.ts`, 10; `test/idiomas.test.ts`, 47).
- `npm run typecheck` limpio y `npm run build` limpio.
- E2E contra staging (`test/e2e/lote2b.e2e.test.ts` y el del lote 2): 4 de 4.
- Navegador (Chromium, escritorio 1280 y móvil 390): Presupuestos en español, alemán y japonés; ⌘K; exportar con
  «Todo» bajó 205 registros en dos páginas, con BOM y las cabeceras de la app.
- Safari de iOS (simulador iPhone 17 Pro): la página nueva carga y detecta el español.
- Evidencia: `~/Claude/entregas/2026-11-14-yala-web-lote-2b/evidencia/`.

## Guion para el iPhone 14 (necesita la cuenta de Jürgen o Face ID: no se declara probado)

El iPhone 14 estaba espejado por otra app durante la sesión, y entrar en la web desde el teléfono pide Apple, Google o el
QR con Face ID.

1. En el iPhone 14, abre Safari en <https://yala-web-staging.misty-surf-6866.workers.dev> y entra con tu cuenta de la
   nube (Apple o Google).
2. Abajo, toca **Más › Presupuestos**. Esperado: los mismos presupuestos y las mismas cifras que Planificación ›
   Presupuestos en Yala Dev, en los bloques Excedidos, Activos e Inactivos.
3. Toca la **lupa** de arriba y escribe el nombre de una categoría. Esperado: la búsqueda sale arriba y el teclado no la
   tapa. Toca la categoría: abre Registros filtrado.
4. En Registros, toca **Exportar CSV**. Esperado: Safari descarga `yala-registros-<fecha>.csv`. Ábrelo en Archivos: las
   tildes se leen bien.
5. Si tienes un pago planificado ya pagado este mes con fecha futura, ábrelo en **Más › Pagos planificados**. Esperado:
   la fila dice «Pagado» y no suma en «Por pagar», igual que en el iPhone.
6. En **Más › Configurar › Idioma**, elige «Deutsch» y luego «Como el navegador». Esperado: la web cambia de idioma y
   vuelve al español.
