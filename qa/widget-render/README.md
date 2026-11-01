# Banco de capturas de los widgets

Pinta **todos los widgets de `YalaWidgets` en todos sus tamaños** con la foto real que escribe la app, sin pasar por la
galería de la pantalla de inicio. Nació en la auditoría de los widgets 2.2 (S35f,
`docs/widgets/AUDITORIA-WIDGETS-2-2.md`) porque añadir widgets a mano en el simulador cuesta ~15 gestos por widget y se
borran al reinstalar la app.

## Qué hace

1. `prepare-sources.sh` copia las fuentes del widget a `Generated/` con cinco cambios (ver su cabecera): sin `@main`, el
   entorno de WidgetKit (`widgetFamily`, `widgetRenderingMode`, `showsWidgetContainerBackground`) pasa a claves que el
   banco fija, el reloj pasa a `RenderClock`, `createEntry` deja de ser privado y `AccessoryWidgetBackground` se imita.
2. `project.yml` (xcodegen) monta una app `WidgetRender` con esas fuentes y los `.strings` del widget.
3. La app carga la foto (`-snapshot`), fija el reloj a su hora y pinta el catálogo (`Harness/Catalog.swift`) con
   `ImageRenderer` en `Documents/out/`.

## Cómo se usa

```bash
# 1. Compilar SIN simulador arrancado (pipeline de la Mini)
qa/widget-render/render.sh build "$(pwd)"
# 2. Arrancar el simulador y pintar
xcrun simctl boot <udid>
qa/widget-render/render.sh run qa/widget-render/fixtures/realista-2026-10-31.plist capturas/widgets/despues
# Opcional: un solo widget
qa/widget-render/render.sh run <foto> <salida> saldo
# Hoja de contactos para mirar varios a la vez
python3 qa/widget-render/contact-sheet.py hoja.png 1500 capturas/widgets/despues/*-claro.png
```

**El «antes» de un cambio** sale del código de la rama base: `git archive HEAD YalaWidgets Yala/App/Logic/Helpers
Yala/Shared/ControlCenterIntents.swift | tar -x -C <carpeta>` y `render.sh build <carpeta>`. Si el catálogo nombra tipos
que la base no tiene, compílala con el catálogo de esa base.

## Nombres

`<widget>-<tamaño>-<modo>.png` · tamaño `s m l xl xlv circ rect`, y `m-se l-se` (iPhone SE, 321 × 148 y 321 × 324) en los de Categorías · modo `claro oscuro standby tintado`.

## Lo que imita y lo que no

- **Medidas**: iPhone 17 Pro (casillas de 164 × 164, 344 × 164, 344 × 364, extragrande vertical 344 × 564) con los
  márgenes de contenido del sistema (16 pt). El extragrande de iPad es aproximado (715 × 330).
- **StandBy**: sin tarjeta, sobre negro, oscuro, solo tamaño pequeño (lo que hace el sistema).
- **Tintado**: APROXIMADO. Pinta con `widgetRenderingMode == .accented` y pasa todo a blanco conservando la opacidad;
  el sistema además tiñe lo marcado con `widgetAccentable()`. Sirve para ver lo que se pierde (un icono blanco sobre un
  relleno opaco), no para juzgar el tinte: eso se mira en el simulador o en el teléfono.
- **Pantalla bloqueada**: vibrante imitado con modo oscuro sobre un fondo oscuro.
- No pinta los controles del Centro de Control.

## La foto

`fixtures/realista-2026-10-31.plist`: lo que escribe la app en el App Group con `-uitest-seed realista` (2 cuentas,
6 presupuestos, 8 pagos, dos años de movimientos), con `defaultPeriod = thisMonth`. Se congela a propósito: antes y
después de un cambio se pintan con los mismos datos y el mismo «ahora» (31-oct-2026, 20:06 de Lima). Para sacar otra:
`export-snapshot.sh <salida.plist>` con Yala Dev sembrada y relanzada sin semilla.

`fixtures/grupos-2026-11-01.plist` (S35f3, widget de Grupos): la de `-uitest-seed grupos` con
`-uitest-fake-cloud-session -uitest-groups-consent` (dos grupos, te deben S/ 330 + $ 46.67), relanzada sin semilla. La
foto de `realista` no trae grupos: con ella el widget de Grupos dice «Abre Yala para ver tus grupos».
