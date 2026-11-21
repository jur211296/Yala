---
name: medir-que-cabe-sobre-un-boton-fijo
description: Cómo medir en la app qué se ve sin bajar sobre una safeAreaBar (oferta Pro, 20-nov-2026): frame .global contra el minY del botón, no ScrollGeometry
metadata:
  type: reference
---

Para decir «qué entra sin scroll» en una hoja con botón fijo (`safeAreaBar`), mide en la app y no en la captura:
`onGeometryChange { $0.frame(in: .global).maxY }` en cada pieza y `.minY` en el propio botón, a un fichero de
`Documents` que se lee con `simctl get_app_container … data`. Comparar es restar. Medido el 2026-11-20 en la oferta de
Primeros pasos (SE 605, 17 Pro 778, Pro Max 860 de botón).

**Why:** el primer intento con `onScrollGeometryChange` (`containerSize - contentInsets`) y `frame(in: .scrollView)`
dio un «visible» de 464 pt en el 17 Pro con los planes claramente a la vista: los dos espacios no casan con la
pantalla. Costó dos builds.

**How to apply:** arnés por argumento (`-mockOffer X`) dentro del cuerpo real, lanzado con `simctl launch` y los args de
`launchForUITest` (ojo: sin `-uitest-skip-onboarding` sale la bienvenida). En zsh, `${=6:-"0 A"}` NO parte la lista
por defecto: pásala explícita. Parche de ejemplo: `docs/maquetas/oferta-pro-primeros-pasos/arnes-maquetas-oferta-pro.patch`.
Relacionado: [[maqueta-de-variantes-por-xcuitest]], [[arnes-de-maquetas-dentro-de-la-app]].
