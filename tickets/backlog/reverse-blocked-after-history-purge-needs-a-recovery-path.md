---
id: reverse-blocked-after-history-purge-needs-a-recovery-path
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-11-17
updated: 2026-11-17
source: "encargo «Arreglar que Volver a tu iCloud deje el iPhone sin datos» (ticket reverse-on-the-iphone-left-the-local-store-empty)"
---

# Los teléfonos que ya purgaron el historial en la nube no pueden volver a su iCloud

## Qué pasa para quien usa Yala

En Ajustes › «Dónde viven tus datos», en vez del botón «Volver a tu iCloud» sale: «En este dispositivo no puedes volver a
tu iCloud: se perdería lo que hiciste en tu cuenta de Yala. Tus datos están a salvo en ella y puedes seguir usándola.»
Le pasa a quien pasó de su iCloud a su cuenta de Yala y estuvo en la nube con la versión que purgaba el historial (desde
julio de 2026 hasta el arreglo del 17-nov). Sus datos están a salvo en la cuenta de Yala; lo que pierde es el camino de
vuelta.

## Por qué no se le deja volver

Medido en el iPhone 14 el 2026-11-17 (ticket `reverse-on-the-iphone-left-the-local-store-empty`): la purga del historial
de la época en la nube caduca la posición del espejo de iCloud. Al remontarlo, su exportación falla con 134301 y su
«reset» borra todas las filas del store. En el relanzamiento siguiente vuelve a bajar de iCloud lo que había ANTES de la
nube: lo hecho en la nube se pierde en el teléfono (el backend congelado lo conserva). El arreglo apagó la purga (los
teléfonos nuevos ya no llegan a este estado) y cerró la vuelta a los que ya purgaron.

## Opciones para recuperarlos (decisión de producto, sin medir)

- **A. Dejar que el espejo se reinicie y volver a bajar la cuenta encima.** Remontar primero el espejo (que se reinicie y
  baje lo de iCloud) y DESPUÉS volver a traer lo de la cuenta de Yala, que aplicaría por identidad sobre lo bajado y el
  espejo exportaría como cambios nuevos. Reordena la vuelta para este caso: más código en la máquina de estados, y el
  teléfono queda unos minutos con los datos viejos de iCloud a la vista.
- **B. Quitar al espejo su posición caducada antes de remontar.** No se reinicia y no borra, pero lo hecho en la nube
  que no tiene registro en iCloud no se exporta nunca (no está en el historial): la espera de la subida no termina y sale
  por su techo. Sin un modo de forzar la exportación, no resuelve.
- **C. Dejarlo cerrado.** Quien quiera volver a su iCloud lo hace desde un teléfono nuevo o tras «Vaciar datos».

Recomendación: medir primero cuántos teléfonos lo tienen (canario `cloudReverseMirrorHistoryExpired`) antes de construir A.

## Relacionado

- `.claude/rules/swiftdata-cloudkit.md`, regla «La vuelta a iCloud necesita el historial ENTERO desde donde lo dejó el
  espejo».
- `Yala/Services/CloudSync/MirrorHistoryProbe.swift`.
