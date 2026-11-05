---
id: panel-recalculates-everything-on-every-return-to-the-tab
status: done
priority: medium
area: "performance, panel"
created: 2026-10-30
updated: 2026-11-05
card: tablero-volver-al-panel-lo-recarga-y-recalcula-e-zpgm
source: "encargo eficiencia-carga-por-vista (S27e), medido en el simulador"
---

# Volver al Panel lo recarga y lo recalcula entero

## Qué pasa

`PanelView.onAppear` llama a `viewModel.reloadAndRecalculate()` en CADA aparición: volver de otra pestaña repite el
fetch de todos los movimientos y el cálculo de todos los widgets aunque no haya cambiado nada. Los cambios de datos ya
llegan por `dataVersion` (`PanelDataFilterObservers`).

Medido el 2026-10-30 con `LoadTimesUITests` (corpus `rendimiento`, 2.337 movimientos, iPhone 17 Pro, iOS 27.0):
**~0,70 s** cada vuelta al Panel (mediana de 5, rango 0,69–0,70 s), con el hilo principal ocupado.

## Por qué no se arregló en el encargo

Quitar la recarga cambia cuándo el Panel ve un cambio que no pasó por `dataVersion` (un escritor que no avise). Hay que
inventariar antes todos los escritores de movimientos, cuentas, presupuestos y subcategorías y comprobar que todos
avisan; si alguno no, el Panel enseñaría datos viejos hasta el siguiente aviso. No es un arreglo «sin cambiar
comportamiento» hasta medir eso.

## Hecho cuando

Volver al Panel sin cambios no recarga (o recarga sin recalcular si la firma de los datos no cambió), con el inventario
de escritores hecho y un test que lo fije; la medida de vuelta baja.

## Hecho (lote P2, 2026-11-05)

- Volver al Panel solo recarga si cambió su firma (`PanelReloadFreshness`): `dataVersion`, CUALQUIER guardado de
  SwiftData en el proceso (`StoreSaveCounter`, `ModelContext.didSave` de cualquier contexto y de los dos almacenes), el
  día, cambios sin guardar en el contexto del Panel, o un cálculo que se canceló a medias al salir.
- **Inventario de escritores** (medido por fichero, no trazado uno a uno): 121 ficheros de `Yala/` guardan en
  SwiftData y 75 no llaman a `incrementDataVersion` en el mismo fichero (parte avisa a través de su llamador). Por eso la
  firma no se fía solo de `dataVersion`: el contador de guardados los cubre a todos por construcción. Lo que sigue sin
  verse al volver es un cambio que ni se guarda ni avisa (regla en `swiftui-ds.md`).
- Medido en el simulador (`LoadTimesUITests`, 5 recorridos): volver al Panel 0,71 s → ~0,22 s (lo que queda es pintar).
- Tests: `PanelReloadFreshnessLogicTests`, `PanelReturnFreshnessViewModelTests` (incluye un escritor silencioso de otro
  contexto), `PanelReturnFreshnessWiringTests`.

## Cómo medirlo en el iPhone

`LoadTimeMarks` solo escribe en DEBUG (en Release es no-op), así que la medida en el teléfono va con el scheme
`Yala Dev` instalado desde Xcode, con datos de volumen:
1. Conecta el iPhone, elige el scheme **Yala Dev** y el iPhone como destino, y dale a Run (⌘R).
2. En la Mac abre **Consola**, elige el iPhone en la barra lateral, escribe `app.yala.perf` en el buscador y pulsa
   Iniciar.
3. Cierra Yala del todo (deslizar en el multitarea) y ábrela; luego cambia a Estadísticas y vuelve al Panel, cinco veces.
4. Las líneas `PERF arranque`, `PERF panel` y `PERF widgets` traen los milisegundos. En el simulador, con el mismo
   corpus: arranque 4,67 → 3,62 s; volver al Panel 0,71 → ~0,22 s; caché de widgets una reconstrucción por arranque
   en vez de dos (medianas de 5, PR del lote P2).
