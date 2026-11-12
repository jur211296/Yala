---
id: first-photo-after-install-fails-on-a-shared-burst-limit
status: done
priority: medium
area: "ia, gateway, attest"
created: 2026-10-21
updated: 2026-10-22
source: "tablero-la-primera-foto-tras-instalar-falla-al-m-vv0k (QA guiado 2026-10-19)"
---

# La primera foto tras instalar falla al instante con «No pude leerla esta vez»

## En lenguaje de usuario

Recién instalada Yala y recién comprado Pro, la primera foto falla en el acto diciendo que falló la lectura. Minutos
después la segunda funciona.

## Lo medido (2026-10-21, en el código)

- El gateway cuenta la «ráfaga» (peticiones por minuto) en UNA lista por teléfono (`gateway/src/rate_limiter.ts`), y esa
  lista la llenan también la sincronización, Grupos y los tipos de cambio (`gateRequest(..., "sync" | "rates")`). Una
  foto del plan free (tope 5/min) se comparaba contra la lista entera: tras instalar, el arranque y la sincronización
  pasan de 5 peticiones en un minuto y la foto recibe un 429 `yala_quota_burst` sin llegar a OpenAI.
- La app no distinguía ese 429: la foto lo pintaba como `.generic` («falló la lectura»), y ese camino no emitía ningún
  canario. Por eso no llegó nada a las 18:45.
- El token de sesión del gateway lleva el plan dentro y vive 15 min: tras comprar Pro, el gateway seguía viendo «free».
- INFERIDO: que el 429 de ráfaga fue lo que vio el iPhone de QA (no hay `wrangler tail` de ese momento). Es el único
  error del camino que sale al instante y se cura solo en menos de un minuto.

## Lo que cambia

1. **Gateway:** la ráfaga se cuenta por categoría (`burstBy`); la sincronización ya no le quita el hueco a una foto o a
   una nota de voz. Un estado guardado con la lista global de antes no frena a nadie. **Desplegado el 2026-10-22** en
   staging (`043cdff6`) y producción (`2e2c05c4`).
2. **App, foto y voz:** el 429 de ráfaga dice «Un momento · Llegaron muchas peticiones seguidas desde este teléfono.
   Espera un minuto y vuelve a intentarlo» con «Reintentar»; el 429 de cuota diaria dice «Llegaste al límite de hoy ·
   Por hoy no quedan más lecturas… Se renuevan cada día» con «Registrar a mano» (no dice «mañana»: el cupo se renueva a
   medianoche UTC, las 19:00 en Lima). En una tanda con algo leído, el aviso de las fotos que faltan lo dice también, sin
   «Reintentar», y las fotos que quedaban no se piden. 16 idiomas.
   Aceptado: con la ráfaga por categoría, el techo por minuto de toda la IA suma los de cada categoría (los topes diarios
   no cambian).
3. **App:** comprar o restaurar Pro olvida el token de sesión, así que la siguiente petición ya viaja con el plan nuevo.
4. **Canario `aiEntryReadFailed`** (`photo|<tipo>`, `voice-transcribe|<tipo>`, `voice-parse|<tipo>`): el próximo fallo
   de este camino dice qué contestó el gateway.

## Tests

`gateway/test/ai.session2.test.ts` (ráfaga por categoría, con mutante: volver a la lista global la pone en rojo) y
`YalaTests/AIEntryGatewayLimitTests` (clasificación con el error EXACTO que decodifica el SDK, canario, prioridades).

## Device-QA (Jürgen, tras desplegar el Worker a producción)

1. Borra Yala e instala el TestFlight con este cambio. Haz el onboarding y compra Pro (sandbox).
2. Nada más terminar, abre «Registrar con foto» y haz una foto de un recibo.
3. Esperado: se lee a la primera. Si falla, el texto tiene que decir el motivo (no «falló la lectura»), y dime la hora:
   miro el canario `aiEntryReadFailed`.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
