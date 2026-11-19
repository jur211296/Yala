---
id: 2026-11-19-barrido-qa-2-3-post-flujo
status: done
priority: high
area: "qa"
created: 2026-11-19
updated: 2026-11-19
source: "encargo de Jürgen del 18-nov: tras Flujo de caja, CI, TestFlight y un barrido de QA (esta es la tercera sesión)"
---

# Barrido de QA de la 2.3 sobre la build 4 de TestFlight

Recorrer la 2.3 en iPhone 17 Pro y SE, iPad y Duo, en claro, oscuro y con el texto al máximo, con foco en lo nuevo desde
el barrido del 15-nov (Flujo de caja replanteado, Panel, widget, Tendencias, Perfil, hojas de cuenta), y comprobar que
las cifras de cierre de mes cuadran entre Flujo de caja, Panel y widget.

## Resultado

- Cifras: «Al 30» igual en Flujo de caja, Panel, Tendencias y widget, sin plan (68,536.30) y con plan (68,112.77), en
  todos los aparatos recorridos.
- Nada grave. Tres cards: texto al máximo en el SE (media), comienzo de mes distinto entre Panel y Flujo de caja (baja),
  propuesta de «Crear mi plan» que cambió con los mismos datos (baja).
- No recorrido, por decisión de Jürgen al llegar al tope de 30 min: SE con texto al máximo en Pagos, Presupuestos,
  Cuentas y Registros; Duo en Flujo de caja y abierto.
- Tres pruebas cortas para el iPhone de Jürgen con la build 4.

Detalle, tabla del recorrido y guion: `docs/qa/barrido-2-3-post-flujo/lista.md`.
