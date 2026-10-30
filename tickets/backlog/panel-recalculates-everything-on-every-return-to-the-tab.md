---
id: panel-recalculates-everything-on-every-return-to-the-tab
status: backlog
priority: medium
area: "performance, panel"
created: 2026-10-30
updated: 2026-10-30
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
