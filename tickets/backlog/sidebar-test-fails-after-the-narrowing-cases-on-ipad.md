---
id: sidebar-test-fails-after-the-narrowing-cases-on-ipad
status: backlog
priority: low
area: "testing, ipad, adaptativo"
created: 2026-10-03
updated: 2026-10-08
source: "gate de floating-buttons-cover-row-amounts-on-ipad-landscape, 2026-10-03"
---

# En el iPad, el test de la barra lateral falla si corre detrás de los casos de estrechar la ventana

## Qué pasa

`AdaptiveNavigationUITests.test_rootShowsSidebarInWideWindow_andTabBarInCompact` sale rojo en
`YalaLane-Adapt-iPad-Pro-13` (iOS 27.0) cuando corre la suite entera, y verde cuando corre solo:

- Suite entera: **3 de 3 en rojo** — dos sobre el árbol de `floating-buttons-cover-row-amounts-on-ipad-landscape` y
  **uno sobre `2.1` en `3b65622e6`**, sin ese cambio. Mismo mensaje en los tres:
  `AdaptiveNavigationUITests.swift:54: La barra lateral no enseña «Registros».`
- Solo: **2 de 2 en verde**, con el simulador ya caliente.
- Centinela (`sim-libre.sh --vigilar`) a 0 en las cinco corridas: nadie corrió encima.

- **Cuarta, el mismo día** (gate de `cola-b-redesigns-must-hold-up-at-ipad-width`, árbol sobre `0566959d0` de `2.1` con
  ese PR encima): suite entera en rojo con el mismo mensaje y el mismo orden; `test_root…` solo, verde. Centinela a 0
  en las dos. Dato de paso: el simulador venía de `simctl erase` y los casos de estrechar **no se saltaron** (103, 53 y
  33 s), así que «Apps en ventanas» sobrevive a un `erase` (el §6.2 de la receta habla de simuladores *recreados*).

## Lo que se sabe, y lo que no

Medido: en esas corridas los tres casos `test_narrowingTheWindow_*` **no se saltaron** (100+ s cada uno: el simulador
tenía «Apps en ventanas»), y en orden alfabético van justo antes que `test_root…` (con `test_panel…` y `test_record…`
en medio). Inferido, sin comprobar: estrechar y ensanchar la ventana deja algo —la ventana restaurada, su ancho o la
orientación— que el arranque siguiente hereda, y la barra lateral sale sin «Registros».

## Qué hacer

1. Correr `test_narrowingTheWindow_keepsEveryPageOpen_andWideningBringsTheSidebarBack` y a continuación `test_root…`
   (dos `-only-testing`) para confirmar el par.
2. Mirar el árbol en el fallo: ¿la barra lateral está, pero con otro ancho o plegada?
3. Si el origen es el estado que deja el caso de estrechar, que lo devuelva al acabar (`tearDown`), no que el de la raíz
   lo tolere.

## Relacionados

[[ipad-native-app]] · [[floating-buttons-cover-row-amounts-on-ipad-landscape]] (donde salió).

## Medido en 2.1 (triage 2026-10-08)

- `AdaptiveNavigationUITests.swift`: `test_rootShowsSidebarInWideWindow_andTabBarInCompact` en `:43` (aserción en `:54`). Los tres
  `test_narrowingTheWindow_*` están en `:415`, `:441` y `:487`.
- Solo hay `setUp` (`:26`): ni `tearDown` ni `addTeardownBlock`. Sin medir hoy: no corrí simuladores en este triage.
- `low`: es un rojo de orden en la lane del iPad, fuera del CI.

Triage 2026-10-08: abierto · medium → low · AdaptiveNavigationUITests sigue sin tearDown ni addTeardownBlock que devuelva la ventana, y su único commit posterior (6bad63aaa) añade un caso sin tocar el orden.
