---
id: sharing-several-photos-hides-yala
status: qa
priority: medium
area: "share-extension, image-entry, inbox"
created: 2026-10-11
updated: 2026-10-11
source: tablero tablero-yala-no-aparece-al-compartir-varias-capt-3ut5 (reporte de Jürgen, 2026-10-10)
---

# Yala no aparece al compartir varias capturas a la vez

## Qué le pasaba al usuario

Con una captura seleccionada en Fotos, Yala salía en el menú de compartir. Con dos o más, no: la extensión solo se
activaba con una imagen (`NSExtensionActivationSupportsImageWithMaxCount = 1`). Medido en simulador el 2026-10-11:
con 1 foto aparece «Yala Dev», con 3 no (`~/Claude/worktrees/_capturas/2026-10-11-compartir-varias-capturas/`).

## Qué hace ahora

- Yala aparece con 1 a 100 fotos. Guarda las 10 primeras (el mismo tope que el selector de Fotos y los PDF) y la hoja
  de lectura las lee todas: cada foto da sus borradores, que quedan en la Bandeja; «Guardar» los aprueba.
- Con más de 10, la hoja avisa: «Quedaron N fotos sin leer: se leen hasta 10 por vez. Para leerlas, compártelas aparte.»
- Sin Yala Pro se descarta la tanda entera y sale la hoja de Pro una vez. Sin consentimiento de IA la tanda espera.

Decisiones (Paso 0 del encargo, en el PR): la tanda viaja en el nombre de los ficheros de `PendingImages/`
(`SharedImageBatch`), no en el router; la extensión escribe `.part` y renombra al final.

## Verificado

- Unit `SharedImageBatchTests` (reparto, orden, tope, aviso, `Info.plist` atado a la app, borrado de la tanda).
- XCUITest `SharedImageEntryUITests`: 3 fotos dan 3 registros; 12 dan 10 y el aviso de 2.
- Simulador: menú real de Fotos con 3 seleccionadas → aparece Yala Dev; al tocarlo, la extensión escribe
  `batch_<tanda>_00_3.jpg` … `_02_3.jpg` en el App Group.

## Guion de device-QA (iPhone, build de TestFlight o Yala Dev)

1. Con Yala Pro y la sesión lista, abre Fotos y selecciona **3 capturas** de movimientos (comprobantes, avisos del banco).
2. Toca Compartir. **Esperado:** Yala aparece en la fila de apps.
3. Toca Yala. **Esperado:** se abre Yala en el Panel con la hoja «Leyendo» (1 de 3, 2 de 3…) y después «Leí N
   registros» con una fila por movimiento.
4. Cierra la hoja con la X sin guardar. **Esperado:** los borradores están en la Bandeja.
5. Repite con **12 capturas**. **Esperado:** se leen 10 y debajo sale «Quedaron 2 fotos sin leer…».
6. Repite con 10 fotos grandes de la cámara (no capturas). **Esperado:** la extensión no se cierra sola (memoria) y
   llegan las 10.
7. Sin Pro: compartir 3. **Esperado:** la hoja de Yala Pro sale una vez; al volver a la app no vuelve a salir.
