---
id: cloud-hydration-banner-does-not-see-data-that-arrives-after-mount
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-17
source: "review adversarial de `cloud-hydration-spinner-never-gives-up-without-attest` (2026-09-17), lente de carreras (medido con una sonda de SwiftUI)"
---

# «Descargando tus datos…» no se entera de que la pantalla ya tiene datos

## El problema, en lenguaje de usuario

Entro con mi cuenta de la nube en un teléfono nuevo. Mientras baja, apunto un gasto a mano, o empiezan a llegar mis
movimientos. Ya veo datos en pantalla y la píldora «Descargando tus datos…» sigue ahí hasta que termina la descarga
entera.

## Lo medido

- El banner recibe `storeLooksEmpty` del shell (`MainTabView(storeLooksEmpty: !hasExistingData)`,
  `Yala/App/ContentView.swift:202`). El shell lo **vuelve a medir** en cada cambio de `dataVersion`
  (`ContentView.swift:265`), que sube con cada alta, borrado o sincronización.
- Pero el sondeo del banner es un `.task` **sin `id`** (`CloudHydrationBanner.swift:113`), así que su closure se queda
  con el valor con que montó. **Medido por la lente con una sonda de SwiftUI** (macOS, SDK 26): un overlay sobre un
  `TabView` al que el padre pasa `false` a los 0,9 s sigue leyendo `true` en los ticks 4 a 6.
- ⇒ «con datos en pantalla» solo apaga el banner si ya los había al montar. Después, lo único que lo apaga es el primer
  pull cerrado (`hasCompletedFirstPull`).
- El docblock del propio término dice lo contrario: «la pantalla que estás mirando está vacía y por eso te lo explico»
  (`CloudHydrationBanner.swift:41-42`).
- **Consecuencia nueva desde el 2026-09-17**, y rara: con el veredicto de attest terminal el banner se esconde. Si la
  persona apunta algo y luego vuelve el attest, la píldora reaparece encima de sus datos hasta cerrar el primer pull.

## Lo que hay que decidir (Jürgen)

1. **Que desaparezca en cuanto hay datos en pantalla**: `.task(id: storeLooksEmpty)`. Cambia la hidratación normal: con
   una cuenta grande, la píldora se va al aterrizar la primera página, antes de terminar la descarga. El guion de
   `reentry-counts-as-fresh-install` («el aviso desaparece cuando llegan las transacciones») seguiría valiendo.
2. **Que siga hasta cerrar la descarga entera**: es lo que hace hoy. Entonces hay que corregir el docblock del término,
   que promete otra cosa.

## Relación con otros tickets

- `cloud-hydration-spinner-never-gives-up-without-attest` (done) — de donde sale.
- `cloud-hydration-spinner-keeps-spinning-with-the-engine-stopped` — el otro término que el banner no re-evalúa.
- `reentry-counts-as-fresh-install` (qa) — su paso 3 mira justo cuándo desaparece la píldora.
