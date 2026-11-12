# Widgets extragrandes de Yala en la pantalla de inicio del iPhone con iOS 27 (Resumen del mes, Pagos planificados, Entradas y salidas)


Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `widgets-extragrandes-ios27` · Sesión cola **S23** · al cerrar → **S24**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/widgets-extragrandes-ios27-5fir.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Brief per-card (copia íntegra de ~/Claude/tmp-frank/widgets-extragrandes-ios27-5fir.md)

### Widgets extragrandes en el iPhone con iOS 27

Cierre: card en **cierra-sola**; Jürgen eligió opción C («los 3») → implementar, con capturas. Card desbloqueada el 26-oct para la ráfaga cierra-sola.

## Contexto
Card `tablero-widgets-extragrandes-en-el-iphone-con-io-5fir`. Decisión 2026-10-20: los 3 extragrandes (Resumen del mes, Pagos planificados, Entradas y salidas) con `systemExtraLargePortrait`.

## Qué se pide
Implementar los tres en 2.2 (sesión propia), capturas de cada uno en pantalla de inicio iPhone iOS 27. Contenido según lienzo enlazado en la nota de la card.

## Cómo se sabe que está bien
La galería ofrece los tres; capturas en home screen.

## Dependencias / base
Arranca sobre `origin/2.2`. Tras FAB. Sim iOS 27.

## Nota de la card (detalle de contenido y riesgos)

2026-10-26 cola: Cola S23 · brief sesión ~/Claude/tmp-frank/sesion-S23-widgets-extragrandes-ios27.md · al cerrar sesión → S24

Jürgen decidió el 2026-10-20 (sesión del lote decidido 2.2 · 08): opción C, «quiero los 3», y pidió hacerlo en una sesión aparte. Son widgets de WidgetKit para la pantalla de inicio del iPhone, no del Panel de Yala: tamaño systemExtraLargePortrait (iOS 27; 4×6, una página entera, solo vertical) para «Resumen del mes» (hoy solo .systemExtraLarge de iPad), «Pagos planificados» (hoy mediano y grande) y «Entradas y salidas» (hoy pequeño a grande). Contenido según el lienzo enlazado: Resumen del mes = Disponible, Gastos, Entradas y neto + Categorías en círculo + Presupuestos; Pagos planificados = el mes en calendario con los días de pago + próximos pagos + «Te falta pagar este mes»; Entradas y salidas = entradas, salidas y neto + gráfica día a día + reparto por cuenta (WidgetTransaction no trae la cuenta: añadir un campo OPCIONAL en WidgetDataCache y en el widget, o el decode del snapshot viejo apaga todos los widgets). Disponibilidad: el tamaño es iOS 27+, la app es iOS 26+ → supportedFamilies con #available. Textos nuevos en 16 idiomas. Medido el 2026-10-20: galería de Yala Dev en el iPhone 17 Pro con iOS 27 = 20 widgets, ninguno extragrande.

desbloqueada 2026-10-26 · decisión previa · entra a ráfaga cierra-sola tras las de alta

Lienzo: https://claude.ai/artifact/A17gM3xCQH96SWVNxakCaR

## Cierre
Card cierra-sola: termina con `/cerrar-total` (PR a 2.2, card movida, digest y capturas en ~/Claude/worktrees/_capturas/). Solo no cierres si aparece una decisión vital (seguridad, fuerza mayor o diseño que sin definir sea problemático).


## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Widgets nuevos o tamaño nuevo de los que ya están?** → tamaño nuevo de los tres que ya existen: `.systemExtraLargePortrait` se suma a sus `supportedFamilies` detrás de `#available(iOS 27, *)`. La persona los encuentra en la galería con el nombre de siempre y la configuración de siempre (Entradas y salidas sigue eligiendo período; Pagos planificados, automático o a mano).
Alternativa descartada: tres widgets aparte, que duplicarían «kind», nombre y configuración.

**D2 · Contenido** → el del lienzo con la nota de la card: Resumen del mes = Disponible, Gastos, Ingresos y Neto + categorías en círculo + presupuestos; Pagos planificados = el mes en calendario con los días de pago + próximos pagos + «Te falta pagar este mes»; Entradas y salidas = ingresos, gastos y neto + gráfica día a día + reparto por cuenta. En Solo gastos, cada uno esconde lo de ingresos como ya hacen sus tamaños de hoy.

**D3 · El reparto por cuenta: ¿de dónde sale?** → un campo OPCIONAL nuevo en el resumen de cada período (`WidgetPeriodSummary.accountFlows`), calculado en la app con la misma suma que los totales. No de `WidgetTransaction`: la foto solo lleva los 10 últimos movimientos, así que un reparto desde ahí sería falso. Opcional en las dos copias del DTO: una foto vieja decodifica y el bloque simplemente no sale hasta que la app la reescriba.

**D4 · El mes de pagos: ¿de dónde sale?** → otro campo OPCIONAL en la foto (`WidgetDataSnapshot.paymentsMonth`): días con pago pendiente y pagado del mes, y lo que falta pagar convertido a la divisa principal, con la misma cuenta que la tarjeta de Pagos del Panel (ocurrencias del mes, saltadas fuera, pagadas al importe real). El widget no puede: no tiene tipos de cambio ni las recurrencias. Con una foto de otro mes, el calendario sale sin marcas y sin la cifra.

**D5 · Textos nuevos** → tres claves en los 16 locales: «Neto», «Por cuenta» y «Te falta pagar este mes». Lo demás reusa claves existentes (Disponible, Gastos, Ingresos, Categorías, Presupuestos, Pagos planificados).

**D6 · Toques** → los del lienzo (L15-3): cifras → Panel, círculo → Distribución, presupuestos → Presupuestos; Pagos → Pagos planificados (o crear uno si no hay); Entradas y salidas → Tendencias.

**D7 · Verificación** → unit del cálculo nuevo de la app (reparto por cuenta suma el neto; pagos del mes) y del DTO (paridad y foto vieja); capturas de los tres en la pantalla de inicio del iPhone 17 Pro con iOS 27.0. No hay XCUITest de widgets en el repo (SpringBoard), así que el área va a `manual` con las capturas como evidencia.
