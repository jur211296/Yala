# Tanda de QA de Jürgen — 2.2, barrido C del 2026-11-03

Barrido con `/barrido-qa` y el criterio estricto del 24-oct (filtro doble) sobre `origin/2.2` en `b775ebdc6` (#765).
Alcance: lo mergeado **después** del barrido B (`tanda-qa-jurgen-2.2-barrido-2026-11-03.md`, base #760): la prueba de
unslop-design (#761), el arreglo del tuteo en francés (`a7ab7b025`), la cabecera de Grupos (#757), la hoja de varios
registros (#763), los widgets y la venta en otra divisa (#764) y AnnotateKit en Yala Dev (#765). La estabilidad de
Sentry (#760) ya entró en el barrido B; aquí solo se re-mide su estado.

Lo que decidió el barrido B **no se repite**: sus montajes del iPhone y sus preguntas siguen igual, con los dos ajustes
de «Preguntas de visto bueno».

Los ids van sin el prefijo `tablero-`.

## Resumen

- **Revisadas: 7 cards.** Cinco nuevas en «in qa» (`refs`, `ohfu`, `va62`, `s9hp`, `k1xc`), la de la cabecera de
  Grupos (`ao0q`), que seguía en backlog con su PR ya mergeado, y `y29x`, del barrido B, que la cabecera dejó sin
  objeto. Las otras cards en «in qa» son del barrido B o de Lola y no cambian.
- **Pasan a done: 7**, cada una con su motivo y su evidencia en la nota de la card y en la tabla de abajo.
- **Probadas en el simulador: 1** (`ohfu`, el «Ya lo pagué» del widget de Pagos planificados).
- **Para tu iPhone: 0 nuevas.** Ninguna pasa el filtro doble. La tanda del iPhone sigue siendo **la del 30-oct: 8 cards
  en 4 montajes, unos 50 min**, con el guion de `tanda-qa-jurgen-2.2-barrido-2026-10-30.md`. Nada de #757-#765 cambia
  esos pasos.
- **Preguntas de visto bueno nuevas: 0.** Dos ajustes a las del barrido B (abajo).
- **Decisión pendiente: 1**, la misma (`laik`, Siri gratis con el modelo del iPhone).
- **Sentry (medido por API el 2026-11-03 22:40 Lima):** `YALA-IOS-3` e `IOS-4` ya están resueltos. `YALA-IOS-2` (la
  congelación del iPhone) sigue abierto y **sin eventos desde el 30-oct 23:17 UTC** (build 5); 0 eventos en las
  últimas 24 h. Marcarlo resuelto lo hace Frank con su token de escritura.
- **Pase de estrés:** dos hallazgos, a card (abajo). Ninguno bloquea.
- **Tickets:** ninguno de `tickets/qa/` es de este alcance; no se mueve ninguno.
- **Tiempo:** unas 2 h, casi todo en el simulador.

## Qué bloquea 2.2

Lo mismo que el 30-oct: `046l` (ver el grupo antes de crear cuenta al unirse), montaje A.

## Las pruebas del iPhone

Sin cambios: montajes A (dos aparatos, unirse a un grupo: `046l`, `7xnd`, `ywm1`), B (iCloud real: `ppxk`, `n5zw`,
`7e60`), C (barra personalizada: `fozu`) y D (sandbox: `7c97`). Hazlo con el **TestFlight siguiente** al 2.2 (6).

## Preguntas de visto bueno: ajustes a las del barrido B

- **La pregunta 2 (`y29x`, el resumen de Grupos de octubre) se retira.** La sustituyó la cabecera que elegiste en el
  simulador y mergeaste en el PR #757; la card pasa a done.
- **La pregunta 1 (`bvpn`, `jmgh`) enseña una lista de Grupos anterior a esa cabecera.** La captura con el código de
  hoy está en `~/Claude/worktrees/_capturas/barrido-qa-2-2-c/grupos-actual/`. Si Frank la manda, que vaya esa.

## Prueba en el simulador

**`ohfu` · «Ya lo pagué» en el widget de Pagos planificados** (iPhone 17 Pro, iOS 27.2, Yala Dev en Debug-Dev).

| Paso | Esperado | Resultado |
|---|---|---|
| Semilla con un pago «una sola vez» que vence hoy (`-uitest-scheduled-due-today`) | «Recibo vence hoy · Vence hoy · −S/ 75» en Pagos planificados | ✓ |
| Widget mediano de Pagos planificados en la pantalla de inicio | La fila de hoy lleva el ✓ y las demás no | ✓ |
| Tocar el ✓ con un toque sintético | La fila pasa a «Pagado» | ✗ **el toque no llega al intent** (ni `axe tap`, ni `touch`, ni `--tap-style physical`; el log de la extensión no registra nada). El toque en el cuerpo del widget sí abre Yala. Límite de la herramienta, no del código (inferido, no medido) |
| Petición escrita en la cola del App Group como la deja el intent, y Yala a primer plano | Registro con el monto, la cuenta y la categoría del pago; el pago pasa a pagado | ✓ registro −S/ 75 «Recibo vence hoy»; el pago queda inactivo con su fecha de pago; balance 6,279 → 6,204 |

Por qué no va a tu iPhone: el único eslabón sin conducir es el dedo sobre el ✓, y si falla no pasa nada (el pago sigue
en Yala para pagarlo ahí): no hay pérdida ni duplicado de datos. El drenaje, el «sin duplicar» y el descarte de los
compartidos los fija `ScheduledPaymentWidgetPayTests`. Capturas en
`~/Claude/worktrees/_capturas/barrido-qa-2-2-c/widget-ya-lo-pague-ohfu/`.

Trampa medida: `xcrun simctl spawn … defaults write group.…` **no** escribe en el App Group de la app, sino en las
preferencias del usuario del simulador. Para meter algo en la cola hay que matar el `cfprefsd` del runtime y escribir el
plist de `Containers/Shared/AppGroup/<id>/Library/Preferences/` con `plistlib`. Y bajo `-uitest` el arranque no drena
las colas: lo hace la vuelta a primer plano.

## Pase de estrés

iPhone 17e y iPhone 17 Pro Max (iOS 27.2), Dynamic Type AX5 y modo oscuro, sobre lo nuevo con UI: la cabecera de Grupos
y la hoja de varios registros. Los widgets no escalan con el tamaño de texto y no se repasan. Capturas en
`~/Claude/worktrees/_capturas/barrido-qa-2-2-c/pase-estres/`. Simuladores creados y borrados al terminar.

| Hallazgo | Card |
|---|---|
| La hoja «Leí 7 registros» deja la lista en una franja de ~150 pt en el 17e (~400 en el Pro Max): el aviso ámbar y los botones van fijos fuera del scroll. El total sale «S/2….71» y el botón «Guar-dar…» | `pase-de-estres-2-2-c-con-el-texto-al-max-48ri` (media) |
| En Grupos, la cifra del neto (tamaño fijo por diseño) queda menor que las líneas de «Te deben», que sí escalan; el hero del Panel hace lo mismo. «Nuevo gasto / Nuevo grupo» salen «Nu…» y «N…» | `pase-de-estres-2-2-c-con-el-texto-al-max-ysol` (baja) |

Ninguno es barato de arreglar en un PR de docs; los dos van a `ready to launch` con cierre autónomo.

## Lo que pasó a done

| Card | Motivo y evidencia |
|---|---|
| `refs` · convertir a gasto compartido desde voz o imagen | test del flujo: `CaptureConvertToGroupUITests` (rojo sin el arreglo, verde con él) e `InboxConvertToGroupUITests`. |
| `ohfu` · «Ya lo pagué» en el widget de Pagos | simulador (arriba) + `ScheduledPaymentWidgetPayTests`; el toque en el ✓ no pasa el filtro doble. |
| `va62` · hoja de varios registros | test del flujo: `MultiDraftReviewUITests` (foto con siete, voz con dos) y `MultiDraftReviewLogicTests`; propuesta C elegida por Jürgen sobre el simulador. |
| `s9hp` · prueba de unslop-design | decisión tomada: Jürgen mergeó el PR #761 entero, E3 incluido. |
| `k1xc` · AnnotateKit en Yala Dev | herramienta solo de Debug, no es un flujo de usuario; Release sin rastro. PR #765 mergeado. |
| `ao0q` · cabecera de Grupos (estaba en backlog) | decisión implementada (PR #757) con 13 XCUITest y 49 unitarios; elegida por Jürgen sobre el simulador. |
| `y29x` · el resumen de Grupos de octubre | sin objeto: lo sustituyó la cabecera de `ao0q`. |

## Lo que se queda

Nada nuevo. Lo que ya se quedaba en el barrido B sigue igual y por lo mismo: los montajes A-D por el filtro doble
(dos aparatos, iCloud real, barra personalizada en el teléfono y compras en sandbox), las 5 preguntas de visto bueno que
quedan del barrido B y la decisión `laik`.
