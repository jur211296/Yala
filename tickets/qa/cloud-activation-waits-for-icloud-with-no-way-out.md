---
id: cloud-activation-waits-for-icloud-with-no-way-out
status: qa
priority: medium
area: "modo-nube, settings"
created: 2026-10-19
updated: 2026-10-19
source: "tablero-activar-la-nube-con-6-movimientos-espera-ppxk (QA guiado 2026-10-19)"
---

# «Activar la nube» espera a iCloud minutos, con la pantalla congelada y sin poder cancelar

## En lenguaje de usuario

Con 6 movimientos, «Activar la nube» se queda en «Esperando a que iCloud termine de sincronizar…» más de 5 minutos. No cambia nada en pantalla y «Cancelar la activación» está apagado. Solo avanza si salgo de Yala y vuelvo.

## Lo medido (2026-10-19)

- La espera es la pre-espera de quiescencia (`CloudMigrationController.awaitImportQuiescenceForResume`, sondeo cada 2 s, tope 300 s). `isImportQuiescent` exige 8 s sin un import terminado (`SubcategoryDedupGate`), y no los tuvo.
- «Tras el tope nadie reintenta con la app delante» es **falso en Almacenamiento**: su bucle de 1 s re-kickea cada 30 s. Pero lo hacía con `await`, y mientras esperaba el bucle dejaba de llamar a `refresh()`: la pantalla, congelada en el paso viejo.
- «Cancelar» lleva `isDisabled: controller.isWorking`, y `isWorking` es `true` durante toda la pre-espera.
- Por qué el import no se asienta con un corpus mínimo **no se puede medir en simulador** (sin CloudKit). Queda instrumentado.

## Lo que cambia

1. «Cancelar la activación» se puede tocar durante la pre-espera (`MigrationImportWaitLogic.cancelEnabled`), y la corta (`preWaitCutRequested`). El «sí» se apunta en el runner, que lo honra en cuanto iCloud deje escribir el journal.
2. El re-kick de 30 s de Almacenamiento ya no bloquea el refresco de 1 s: la pantalla sigue al día.
3. Canario `cloudMigrationImportNotSettled` al vencer el tope: si seguía un import en curso o terminaban imports recientes, y cuántos.
4. El texto no cambia: «Esperando a que iCloud termine de sincronizar…» ya decía qué espera.

## Lo que NO cierra

- **El «sí» aterriza cuando iCloud deja escribir.** «Cancelar» corta la pre-espera de la pasada y apunta el «sí» en el runner, pero la cancelación escribe el journal y eso exige la misma quiescencia: si iCloud no se asienta nunca, la cancelación espera con él (con el botón apagado mientras está en marcha, para que un segundo toque no la corte). Lo que sí deja de pasar es que la persona no pueda pedirla.
- «Dejar de esperar» y el «Cancelar» de la bienvenida siguen apagados durante la misma espera: `migration-exits-stay-disabled-during-the-import-pre-wait`.

El `hechaCuando` («con pocos datos, termina en menos de 1 min sin salir de la app») depende de por qué iCloud no se asienta, que está inferido. La otra mitad del bucle se cierra en `cloud-activation-verify-loops-on-accounts`. El canario dirá cuál de las dos formas tiene la flota.

## Tests

`MigrationImportWaitLogicTests` (tabla con control) y `MigrationImportWaitWiringTests` (corte en `cancelMigration` y en cada sondeo; refresco sin `await`). El scan de `SnapshotUploadCeilingLogicTests` sigue al botón.

## Device-QA (Jürgen, iPhone de QA, TestFlight 19)

1. Con un iCloud que traiga cuentas duplicadas (el del QA del 19-oct), «Activar la nube».
2. Si sale «Esperando a que iCloud termine de sincronizar…»: el botón «Cancelar la activación» tiene que estar **activo**. Tócalo y confirma: la activación tiene que cancelarse en cuanto iCloud se calme (o en el siguiente intento), sin dejarte atrapado.
3. Repite sin cancelar y cronometra: dime si termina sin salir de Yala, y la hora para mirar el canario.
