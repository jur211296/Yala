---
id: reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
source: "medido al implementar `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` (2026-09-22): el gemelo de la espera de SUBIDA, con la misma forma y sin arreglar"
---

# En la espera de subida, un fallo de iCloud de UNA pasada cobra las horas que la espera llevaba por otra cosa

## El problema, en lenguaje de usuario

Llevo tres horas esperando a que mis datos suban a iCloud, sin haber entrado a iCloud todavía. La app espera, que es
lo correcto. Entro a iCloud, y en esa primera pasada el espejo contesta «no autenticado» —cosa habitual justo al
iniciar sesión, y que se arregla sola en la siguiente—. En vez de reintentar, la app cancela la vuelta **en ese mismo
instante** y me dice que iCloud no recibió todos mis datos.

Si eso me hubiera pasado a los dos minutos de empezar, habría esperado y reintentado.

## Por qué pasa (medido el 2026-09-22)

Es el **gemelo exacto** de `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`, en la otra espera.
`MigrationRunner.observeReverseUploadWait` junta dos cosas de procedencias distintas:

- `stalled = observedAt - lastProgressAt` es el tiempo SIN AVANZAR —sin que la cifra de pendientes baje—, venga de
  donde venga. Tres horas sin cuenta iCloud lo llenan igual que tres horas de espejo roto.
- `blocker.stallCause` es de **ESTA** observación, la última (`executor.reverseUploadBlocker()`).

`MigrationStateMachine` aplica el presupuesto de la causa actual al tiempo acumulado
(`guard stalled >= budget`, arista `.reverseUpload + .reverseUploadStalled`). Con 3 h acumuladas y una causa que elige
el techo corto (900 s), sale a la primera: sin histéresis, sin segunda observación y sin un solo reintento.

**El camino está medido, no inferido.** `ReverseUploadBlockerLogic.decide` devuelve `.icloudOff` (techo LARGO) sin
cuenta iCloud, y `.icloudUnusable` (techo CORTO) en cuanto `mirrorReportedNotAuthenticated` se enciende. La transición
de uno a otro es justo lo que pasa cuando alguien entra a iCloud tras horas esperando — y ese testigo «se apaga con
cualquier evento con éxito» según su propia documentación, o sea que el propio código lo trata como pasajero.

## Qué hay que hacer

Lo mismo que se hizo en el techo previo al montaje, y con el mismo mecanismo, que ya está escrito y probado:

1. **Reloj por causa**: el techo corto solo cuenta el tiempo acumulado bajo ESA causa, como racha consecutiva. Dos
   campos aditivos en el journal, al lado de `reverseUploadProgressAt`.
2. **El techo largo sigue por encima con cualquier causa** (`fase >= 72 h OR causa >= 15 min`). Sin esa mitad, dos
   causas definitivas que se alternen re-sellan el reloj corto indefinidamente y la espera vuelve a no tener techo.
3. **Un solo mecanismo para todos los motivos**, como decidió Jürgen para el gemelo.

**No es copiar el diff**: la espera de subida tiene una noción de AVANCE que la otra no tiene —la cifra de pendientes
que baja—, y el reloj de causa tiene que convivir con ese re-sellado. Un avance real reinicia los dos relojes.

## Criterios de aceptación

- [ ] Un `.icloudUnusable` aislado tras una espera larga por otra causa **reintenta al menos una vez** antes de
      cancelar la vuelta.
- [ ] Un `icloudFull` repetido sigue saliendo a los 900 s de espera REAL con esa causa.
- [ ] La falta de cuenta iCloud conserva su techo largo, y un AVANCE de la cifra sigue reiniciando los dos relojes.
- [ ] Test que siembre una espera larga con una causa y observe con otra: hoy sale al instante y debe holdear.
- [ ] Test de que las causas alternándose siguen topando con el techo largo.

## Relacionado

- `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` — el gemelo, ya arreglado; su implementación es
  el molde, con la salvedad del avance.
- `reverse-upload-has-no-ceiling-and-no-exit` — el que creó esta espera y su techo.
- `reverse-upload-ceiling-trusts-a-clock-set-back-during-the-wait` — otro defecto del mismo reloj, independiente.
