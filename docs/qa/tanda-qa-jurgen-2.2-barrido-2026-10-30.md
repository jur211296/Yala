# Tanda de QA de Jürgen — 2.2, barrido del 2026-10-30

Barrido con `/barrido-qa` y el criterio estricto del 24-oct (filtro doble) sobre `origin/2.2` en `a905fdf0b` (#696).
Sustituye, para lo que sigue en «in qa», a la tanda del 24-oct (`tanda-qa-jurgen-2.2-barrido-2026-10-24.md`). Los
guiones largos de Grupos siguen en `tanda-qa-jurgen-2.2-lote14-grupos-invitar.md`; aquí se dice cuál correr.

## Resumen

- **Revisadas:** las 80 cards de Yala en «in qa» (78 de 2.2, más 2 de Lola que no toqué: `b4es`, `eukp`). Quedan 20.
- **Pasan a done: 59**, cada una con su motivo y su evidencia en la nota de la card y en la tabla de abajo.
- **Probado en el simulador: 1 prueba**, tu Excel real en el import (5 cards: `mnox`, `l2g9`, `34qe`, `jvgc`, `7wh5`).
  En verde: los 7 saldos cuadran al céntimo. Detalle abajo, en «Probado en el simulador».
- **Se quedan para tu iPhone: 7 cards en 4 montajes**, unos **50 min**. El 24-oct eran 40 cards y 2 h 30 min.
- **Preguntas de visto bueno: 6**, fuera de la tanda. Frank te las manda una por mensaje, con sus fotos.
- **Decisión pendiente: 1** (`laik`, Siri gratis con el modelo del iPhone).
- **Fuera de QA: 2.** `nmtk` (tarjeta con fecha de corte): su PR #650 **no está en 2.2**: lleva desde el 27-oct en
  cola con un conflicto y `coverage-index` en rojo. Card nueva `la-tarjeta-con-fecha-de-corte-pr-650-lle-uvwn` para
  rebasarlo. `w0a2` (Yala IA ampliada): no es QA, es el encendido en producción tras publicar; pasa a backlog.
- **Cards nuevas: 2.** `uvwn` (rebasar el PR #650) y `6cqd` (el saldo «€ -0.00», 2.3).

Los ids van sin el prefijo `tablero-`.

## Qué bloquea 2.2

| Card | Por qué bloquea | Montaje |
|---|---|---|
| `ux-2-2-l12-17-se-pide-cuenta-y-consentim-046l` | Quien abre una invitación tiene que ver el grupo antes de crear cuenta | A |

## Antes de empezar

1. **Yala Dev compilado desde `2.2`** (Xcode 27.1) contra staging para los montajes A, B y C.
2. **Cuenta de sandbox** de Apple para el montaje D (Ajustes › App Store › Cuenta de sandbox).

## Las pruebas, por montaje

### A · Dos aparatos con Yala Dev contra staging: unirse a un grupo (unos 20 min) — BLOQUEA

**Unirse por invitación, esperar aprobación y entrar** (`046l`, `7xnd`, `ywm1`).
Retiene: §4 inicio de sesión real contra el servidor, dos aparatos y el push real de la aprobación. Si falla, nadie
puede unirse a un grupo. El simulador solo cubre el tramo sin servidor
(`UXAudit22Decidido14UITests/test_realLinkWithoutAccount_showsTheGroupBeforeSigningIn`).
Guion: montaje A, apartados 1 a 4, de `docs/qa/tanda-qa-jurgen-2.2-lote14-grupos-invitar.md` (iPad invita, iPhone se
une).

### B · Tu iCloud real en Yala Dev (unos 25 min)

**B1 · Activar la nube y que no se quede esperando** (`ppxk`, y de paso `igt9`).
Retiene: §4 la importación real de iCloud. Si se queda colgada, la persona no puede pasar a la nube. Antes medimos
9,5 min para 5 movimientos.
1. Con datos en Yala Dev en iCloud privado: Perfil › «Dónde viven tus datos» › «Activar la nube».
2. Apunta la hora al confirmar y la hora de «Nube activa».
3. Mientras sube: «Subir tus datos» lleva su cifra («650 de 1537») y cambia cada pocos segundos. Si sale «Esperar a
   iCloud», «Cancelar» se puede tocar.
4. Pásame las dos horas.

**B2 · Con iCloud Drive apagado los datos siguen** (`n5zw`).
Retiene: §4 apagar iCloud Drive de verdad. Antes la app arrancaba vacía, como si no hubiera datos. Es la segunda
vuelta: el arreglo del 25-oct (PR #625) es distinto del que falló el 19-oct.
1. Con iCloud Drive encendido, abre Yala Dev una vez y apunta cuántos movimientos ves.
2. Cierra Yala del todo. Ajustes › tu nombre › iCloud › iCloud Drive: apágalo.
3. Abre Yala: los mismos movimientos y ningún aviso.
4. Crea un movimiento. Cierra Yala, enciende Drive y ábrela: el movimiento sigue.

**B3 · Cerrar sesión perdiendo cambios no cierra Yala** (`7e60`).
Retiene: §4 el cierre de Yala que viste el 28-oct no sale en el simulador, y el arreglo (PR #666) no demuestra haberlo
cortado. Unos 3 min.
1. Con Yala Dev en la nube, activa el modo avión y apunta un gasto.
2. Ajustes › «Cerrar sesión» › confirma; en el aviso de cambios sin subir, elige perderlos.
3. Bien: sin cerrarse la app, sale el Welcome. Mal: Yala se cierra o queda una pantalla sin nada que tocar. Si se
   cierra, pásame el informe de fallos (Ajustes › Privacidad y seguridad › Análisis y mejoras › Datos de análisis,
   el que empieza por «Yala»).

### C · La barra de abajo personalizada (unos 2 min)

**Grupos y Registros en la barra abren su pantalla** (`fozu`).
Retiene: §4 la pantalla negra que viste el 27-oct no salió en el simulador; `CustomTabBarUITests` cubre el cierre de la
app que sí salió, no la pantalla negra. Sin esto, quien personaliza la barra no llega a Registros ni a Grupos.
1. Más › Ajustes › «Pestañas de abajo».
2. Quita Estadísticas y Planificación, añade Grupos y Registros. Cierra el editor con ✓.
3. Toca Registros, Grupos, Panel y otra vez Registros: cada una abre su pantalla, nunca negro.

### D · Compra en sandbox (unos 5 min)

**Renovar desde «Tu suscripción terminó»** (`7c97`).
Retiene: §4 la causa (StoreKit enseña un rato la suscripción caducada) solo la da el sandbox de Apple; el simulador
compra con un seam. Si falla, quien quiere volver a pagar no puede.
1. Con la suscripción de sandbox caducada y más de 4 cuentas o 3 presupuestos, abre Yala: sale «Tu suscripción
   terminó».
2. «Renovar» › elige un plan › compra › «Comenzar».
3. Bien: vuelves a Yala sin la hoja. Mal: la hoja vuelve a salir.

## Decisión pendiente (no es de la tanda)

`laik` · Siri gratis con el modelo del propio iPhone. Falta tu decisión, y para tomarla la card trae un guion de medida
(tiempo y calidad frente al servidor, en español e inglés). Siri no es un flujo principal: no entra en la tanda.

## Preguntas de visto bueno (no van a la tanda)

Frank te las manda una por mensaje, con sus fotos. Capturas en
`~/Claude/worktrees/_capturas/2026-10-30-barrido-qa-2-2/`, una carpeta por pregunta.

| # | Card | Qué se pregunta | Carpeta |
|---|---|---|---|
| 1 | `17ec` | ¿Te vale el diseño de la tarjeta con varias divisas en el Panel y en su ficha? | `p1-tarjeta-varias-divisas-17ec/` |
| 2 | `igt9`, `27z3` | ¿Te valen los pasos con su cifra de «Activar la nube» y «Volver a iCloud»? | `p2-progreso-nube-igt9-27z3/` |
| 3 | `gulp` | ¿Vale el texto de la única confirmación de «Volver a iCloud»: «Tus datos vuelven a vivir en este dispositivo y en tu iCloud. No pierdes nada.»? | `p3-texto-volver-icloud-gulp/texto.txt` |
| 4 | `1qfi` | ¿Te valen las cabeceras de «Solo gastos» en el Panel y en Estadísticas? | `p4-solo-gastos-1qfi/` |
| 5 | `e7by`, `k2up` | ¿Grupos y Flujo de caja ya se sienten la misma app que Registros y Estadísticas? | `p5-una-sola-yala-e7by-k2up/` |
| 6 | `i00g` | ¿Te valen los estilos nuevos del Welcome y el onboarding? Y una pregunta abierta: ¿igualamos las alineaciones (selectores a la izquierda, onboarding centrado)? | `p6-onboarding-estilos-i00g/` |

## Probado en el simulador

**El import con tu Excel real** (`mnox`, `l2g9`, `34qe`, `jvgc`, `7wh5`): en verde, a done.

Archivo `Yala_Registros_27-oct-2026_con-transferencias.xlsx`, elegido por el selector de archivos de iOS (Perfil ›
«Importar archivo» › «Seleccionar archivo» › Explorar › En mi iPhone), con un XCUITest conductor temporal sobre
`a905fdf0b`, en dos pasadas: con Pro y sin Pro.

| Paso | Esperado | Salió |
|---|---|---|
| Vista previa, con Pro | 2.748 registros, 7 cuentas nuevas, 1 fila de Grupos fuera | «Vamos a importar 2,748 registros en Euros, BCP Débito Dólares, BCP Sueldo Soles, BCP TC Soles, BCP TC Dólares, Sip y Starbucks Card»; «Movimientos de Grupos que no se importan: 1»; «Columnas que no se usan: split_total, split_portion» |
| Importar, con Pro | 2.748 importados y los 7 saldos como la suma del archivo | «2748 registros importados correctamente». Saldos: BCP Débito Dólares $ 23,953.08 · BCP Sueldo Soles S/ 3,439.28 · BCP TC Dólares $ -4,103.30 · BCP TC Soles S/ -14,655.62 · Euros € -0.00 · Sip S/ 1.55 · Starbucks Card S/ 8.50. **Los siete cuadran al céntimo** con la suma del archivo cuenta por cuenta |
| Vista previa, gratis | Elegir las cuentas que caben o «Actualizar a Pro» | «Cuentas nuevas que caben en el plan gratuito: 2. Elige cuáles se crean», las 7 con sus filas, «Actualizar a Pro»; preelige las de más filas. Las filas de las no elegidas salen con su motivo («la cuenta «Euros» no se crea porque no la elegiste») |
| Importar, gratis | Entran solo las elegidas | 2.043 importados; BCP Débito Dólares y BCP Sueldo Soles con el mismo saldo que en la pasada Pro |

Dos notas. (1) Las pasadas corrieron con «Crear categorías nuevas» encendido: con el teléfono de pruebas, que no tiene
tus categorías, las filas con una categoría que no existe no entran y lo dicen fila a fila; en tu iPhone, con tus
categorías, no debería pasar. (2) «Euros € -0.00» es un cero negativo pintado tal cual: card nueva de 2.3,
`una-cuenta-cuyo-saldo-suma-cero-sale-com-6cqd`.

Capturas: `~/Claude/worktrees/_capturas/2026-10-30-barrido-qa-2-2/import-excel-real/` (`pro-*` y `free-*`). El
simulador se borró al terminar: tenía tus datos.

## Lo que pasó a done hoy

| Card | Motivo y evidencia |
|---|---|
| `mnox` · import | probado en el simulador con tu Excel real: 2.748 registros, 7 cuentas y saldos al céntimo (arriba) |
| `l2g9` · import | probado en el simulador con tu Excel real: 2.748 registros, 7 cuentas y saldos al céntimo (arriba) |
| `34qe` · import | probado en el simulador con tu Excel real: 2.748 registros, 7 cuentas y saldos al céntimo (arriba) |
| `jvgc` · import | probado en el simulador con tu Excel real: 2.748 registros, 7 cuentas y saldos al céntimo (arriba) |
| `7wh5` · import | probado en el simulador con tu Excel real: 2.748 registros, 7 cuentas y saldos al céntimo (arriba) |
| `tzpw` · Algunos pagos planificados generan varios borradores idénticos en la B | edge case de dos aparatos cubierto por tests: PR #681, ScheduledPaymentsLote10UITests/test_twoDeletionsInARow_undoBringsBothBack, InboxCrudUITests y la unit de fusión de idénticos (29/29 XCUITest en el PR). Descartar uno ya no se lleva los demás, y eso es lo grave; que dos aparatos generen el mismo vencimiento lo simula el test. |
| `y1cd` · Grupos: siempre un admin tras crear o wipe | fijado por tests y desplegado: GroupsOwnershipFromPullTests, GroupCreateLostResponseTests (y1ru) y GroupsNextColumnPiecesTests (PR #664); g25_01 aplicado en staging y producción. Un grupo sin admin tras un wipe es un camino de pocos usuarios. |
| `rj3b` · «Avisos del grupo» en la lista no se puede quitar: falta una X para de | XCUITest del flujo: GroupsListNoticeAlignmentUITests (la X y los bordes por marco), PR #666. |
| `yc6k` · Barrido iOS 27: animaciones y vistas mal optimizadas en todas las secc | polish visual, no grave: PR #694 con GroupDetailChipsUITests (mutante muerto) y el patrón de S12c/S12d. Lo verás en el uso normal del TestFlight. |
| `f8rj` · Borrar dos registros seguidos en la Bandeja cierra Yala (crash de Swif | XCUITest que reproduce el crash: InboxCrudUITests (dos borrados seguidos deslizando, descartar+borrar+Deshacer y desde el editor; el primero rojo con el código viejo) + InboxPendingRemovalTests e InboxRowPruneCoordinatorTests con mutantes, PR #687. |
| `da5d` · El destino de un favorito de transferencia no viaja por el Modo Nube | no grave: sin la columna el favorito llega sin destino y no se pierde nada. Producción anuncia manifestVersion 4 (curl /config, 26-oct) y el campo de iCloud está desplegado (card 5kxx done). |
| `6mb6` · En Solo grupos, callar Apple Pay y Siri con aviso de activar Yala comp | no grave (avisos que sobran en Solo grupos) y fijado por tests: GroupsOnlyIntentGateTests, UsageModePausedPaymentsTests contra el store real, UsageModeWiringTests (PR #652). |
| `6l5n` · Estadísticas: los chips de pestaña se expanden a tirones y el mes se s | polish visual ya revisado por ti el 27-oct («tirón OK»); el corte de la cápsula lo arregló el PR #661. Animación, no flujo. |
| `229z` · Grupos: la puerta borra los grupos de la era CloudKit al volver al neu | edge case de pocos usuarios (teléfono que viene de 2.0 con grupos de CloudKit) y la card misma dice cerrar con el test de la cadena: GroupsGateLegacyGroupsWipeTests con stores reales en disco + su cableado, PR #686. |
| `usxd` · Notificaciones y avisos in-app: que salten uno tras otro con prioridad | XCUITest del flujo: NoticeOrderUITests y 7 suites más (24 tests) + 231 unit con mutantes muertos, PR #696. El push real de Grupos en orden no es grave: los avisos salen igual. |
| `p0iu` · Pasar de la app completa a solo grupos sin perder datos | XCUITest del flujo completo: UsageModeUITests (ida, vuelta sin registros, conservando, empezar de cero) + UsageModeTests y UsageModeFreshStartWipeTests, PR #649, con capturas en _capturas/2026-10-26-completa-solo-grupos-implementar/. |
| `9y84` · QA 2.2 se cancela: tests unitarios context-based se cuelgan (~65 min) | el job tests del push a 2.2 está en verde: qa.yml en a905fdf0b (2026-10-30 15:19 UTC), success. |
| `tjws` · Registro por voz: onda de voz y texto en vivo mientras hablas | no grave: es solo visual (el audio que va a la IA no cambia, PR #677). Lo verás al usar la voz en el TestFlight. |
| `pz4v` · Sin sesión de nube el Panel se ve vacío y no avisa: solo «Dónde viven  | XCUITest del flujo: PanelSyncSignInNoticeUITests (aviso + botón a la tarjeta, y su control sin nube), PR #666. |
| `ste6` · Siri con IA: ¿tus cuentas y movimientos en Spotlight? ¿Las preguntas a | no grave y fijado por tests: SpotlightIndexTests (qué entra y qué no, excluidas fuera, token estable) + capturas despues-2..6 en _capturas/siri-atajos-spotlight/, PR #676. |
| `p4wu` · Subir el TestFlight v1 de 2.2 (UX) | build subido (TestFlight 2.2 v1); la operación está hecha y los TestFlight siguientes ya lo sustituyen. |
| `3nnn` · Subir TestFlight 2.2 (3) con lo mergeado hasta «Lo que te falta pagar» | build 2.2 (3) subido y en TestFlight; sustituido por 2.2 (4). |
| `ikbw` · Subir TestFlight 2.2 (4) con lo mergeado hasta la puerta de Grupos (op | build 2.2 (4) subido y en TestFlight; la siguiente subida es S28tf. |
| `0443` · Tocar una notificación abre su destino exacto (hoy una automática abre | XCUITest del flujo: 13 XCUITest nuevos (62 en 11 suites en el gate) y la regla con tests de la puerta real, PR #697. El banner de iOS lo pinta el sistema. |
| `vbf9` · Tras activar la nube en un aparato, el otro no lo propone solo: hay qu | no grave (el aviso solo ahorra buscar el botón) y fijado por CloudAdoptOfferUITests (con el marcador sale, sin él no), PR #625. Usa el molde de aviso que ya existía. |
| `zvdt` · Vaciar datos mantiene la cuenta y no lleva al Welcome; Eliminar cuenta | XCUITest de los dos caminos: WipeAndDeleteAccountLandingUITests (Vaciar → Panel con la cuenta; Eliminar → Welcome) + RemoteWipeCutTests, AccountDeletionServiceTests y DestructiveScopeLogicTests, review adversarial, PR #688. Capturas en _capturas/2026-10-29-vaciar-datos-mantiene-cuenta/. |
| `feer` · Welcome: las pantallas entran desde arriba con un flash negro entre pa | polish visual: vídeos antes/después (también con Reducir movimiento) en _capturas/2026-10-28-welcome-transiciones-pasos/ y WelcomeCoverContentLogicTests con mutantes, PR #662. |
| `5fir` · Widgets extragrandes en el iPhone con iOS 27 | hecho como lo elegiste (opción C): capturas de los tres en la pantalla de inicio del iPhone 17 Pro con iOS 27 en _capturas/widgets-extragrandes-ios27/ y WidgetExtraLargePortraitDataTests, PR #679. |
| `qb1r` · UX 2.2 · L16-5 · El idioma de la app solo se cambia si lo elegiste en  | XCUITest del flujo (es → en → es, reabre Personalización y el avatar vuelve a abrir Ajustes): verde 3 de 3 con el arreglo del PR #618, rojo sin él. Cambiar el idioma no es un flujo grave. |
| `x468` · UX 2.2 · L12-14 · El enlace se manda solo, sin un texto que diga qué e | no grave (el texto que acompaña al enlace) y fijado por UXAudit22Decidido14UITests, PR #593. |
| `d4ad` · UX 2.2 · L12-8 · El permiso de avisos de grupo se pide en una alerta s | no grave (cuándo se pide el permiso de avisos), PR #593. |
| `mhtg` · UX 2.2 · L12-12 · «Crear mi primer grupo» desde la bienvenida son 9 pa | no grave (número de pantallas para crear el primer grupo); UXAudit22Lote12y13UITests, PR #647/#593. Crear un grupo con sesión real lo ejercitas en la prueba de dos aparatos. |
| `c42m` · UX 2.2 · L12-4 · El paso 3 del educativo y el consentimiento cuentan l | no grave (fusión de dos pantallas del educativo); XCUITest del lote 13. |
| `5tex` · UX 2.2 · L13-8 · Desde el Panel sin grupos, «Grupo» lleva a «¿Cómo fun | no grave (adónde lleva «Grupo» desde el Panel sin grupos); XCUITest del lote 13. |
| `i104` · UI 2.2 · L12-10 · Al guardar un grupo no se propone invitar a nadie | no grave (la propuesta de invitar al guardar) y fijado por XCUITest del lote 12/13. |
| `fptw` · El permiso de avisos de grupo ya no se pide a quien llega a su primer  | no grave (cuándo se pide el permiso de avisos). |
| `ewvm` · Al volver a entrar por «Vengo por un grupo» con la misma cuenta, Yala  | no grave (se repite una pantalla de consentimiento) y edge case de pocos usuarios (volver con la misma cuenta por «Vengo por un grupo»). |
| `qqo7` · UX 2.2 · Entrar con Google en un iPhone que usó Apple: «Esa cuenta usa | no grave (un texto que confunde) y edge case de pocos usuarios (Google en un iPhone que usó Apple). |
| `ypit` · «Reabre Yala» solo cuando la persona entra en su iCloud privado; en la | no grave (cuándo se pide reabrir Yala). |
| `apsn` · Al elegir «Vengo por un grupo» la pantalla se queda negra unos 10 s an | no grave (unos segundos de espera en negro, no bloquea la entrada). |
| `k4gd` · Auditoría UX 2.2 · lote 5: primeros días, guías y tips | no grave (textos y guías de los primeros días); lo grave de esa zona, entrar con Apple o Google, lo ejercita la prueba de unirse a un grupo de la tanda. |
| `trc6` · Al terminar de importar un archivo no sale «Importación completada» | no grave: la importación se hace y solo se pierde el aviso de «Importación completada». Además el import se probó en este barrido con tu Excel real. |
| `1a5m` · Tartas y rankings: trozo «Sin categoría» en gris (opción A) | decisión tomada (opción A) e implementada; las tartas y rankings del Panel la fijan sus tests. El widget usa el mismo cálculo. |
| `pbcq` · Desplegar «cambiar el rol de un miembro» (g22_01 y Worker) en staging  | desplegado en staging y producción y fijado por GroupMembersAdminUITests; cambiar el rol no es un flujo principal. |
| `qp67` · UX 2.2 · L18-8 · «Este mes y futuros» cambia también los meses pasados | el campo CD_amountChangesRaw está desplegado en Production (card al5y done) y el cálculo local está probado con capturas. Que un campo ya desplegado viaje por iCloud no cambia con este arreglo. |
| `ax7s` · UX 2.2 · L2-14 · Un favorito guardado desde una transferencia queda «S | el campo CD_destinationAccount está desplegado (card 5kxx done) y FavoritePaymentDestinationMigrationTests + TransactionFormDecided02UITests/test_transferFavorite_setsBothAccounts lo fijan en local. No grave. |
| `hov2` · UX 2.2 · L6-13 · «Conectando con tu cuenta…» puede tardar minutos sin  | solo pedía cronometrar en producción; el criterio estricto no retiene una medida de tiempo. Lo verás al entrar con tu cuenta en el TestFlight. |
| `vv0k` · La primera foto tras instalar falla al momento con «No pude leerla est | no grave (la segunda foto funciona) y su arreglo del límite compartido está en 2.2. |
| `i9rh` · Tarjeta con varias divisas, entrega 3: se elige la tarjeta y la divisa | no grave (el borrador se revisa antes de guardar) y fijado por ApplePayCurrencyHintTests y AccountLinesUITests. |
| `egjm` · Integrar Yala con el nuevo Siri con IA de iOS 27 | Siri no es un flujo principal; las rutas las fijan SiriShortcut*/SiriEntryRouteTests en verde. |
| `wewa` · UX 2.2 · L15-5 · En 10 de los 16 idiomas, ninguna frase de Siri funcio | Siri en otros idiomas no es un flujo principal; las frases las fija la paridad de idiomas. |
| `vq9a` · UX 2.2 · L15-15 · No hay accesos rápidos al mantener pulsado el icono | no grave (accesos rápidos del icono). |
| `g8rc` · Declarar el entitlement de App Attest después de activarlo en el App I | el build Debug del scheme Yala no llega a ningún usuario; App Attest de producción lo ejercita cualquier pregunta a Yala IA en el TestFlight. |
| `fleb` · UX 2.2 · L17-9 · Tras comprar, Yala no te devuelve a lo que querías ha | no grave (adónde vuelves tras comprar). |
| `u5pi` · UI 2.2 · L17-6 · Al terminar la prueba salen dos hojas seguidas y la p | no grave (dos hojas seguidas al terminar la prueba); fijado por SettingsLote15UITests. |
| `ds09` · Quien entra por «Ya tengo una cuenta» vuelve a ver todos los tips de p | no grave (vuelven a salir las guías de principiante). |
| `qo1l` · UX 2.2 · L15-11 · Una ventana de Yala se queda con un indicador de car | edge case de pocos usuarios (iPad con dos ventanas y cerrar sesión en una). |
| `neah` · UX 2.2 · L15-12 · Soltar un recibo en el iPad con algo abierto no hace | edge case de pocos usuarios (soltar un recibo en el iPad con algo abierto). |
| `aw34` · UX 2.2 · L12-15 · La web de invitación no dice qué hacer tras instalar | la web de invitación de 2.2 está publicada (card 4c8w done) y lo grave de unirse lo prueba 046l en la tanda. «Abrir en Yala» es el camino secundario. |

## Lo que se queda y qué lo retiene

| Card | Lo retiene | Dónde |
|---|---|---|
| `046l` | §4 inicio de sesión real y servidor; unirse a un grupo es un flujo principal. BLOQUEA | A |
| `7xnd`, `ywm1` | §4 dos aparatos y push real de la aprobación; sin ella el que espera no entra | A |
| `ppxk` | §4 importación real de iCloud; activar la nube se quedaba esperando | B1 |
| `n5zw` | §4 apagar iCloud Drive de verdad; la app arrancaba vacía | B2 |
| `7e60` | §4 el cierre de Yala no sale en el simulador; arreglo sin demostrar | B3 |
| `fozu` | §4 la pantalla negra no sale en el simulador; sin arreglo, Registros y Grupos no abren | C |
| `7c97` | §4 sandbox de Apple; sin arreglo, no se puede volver a pagar | D |
| `17ec` | §2.6 visto bueno al diseño | pregunta 1 |
| `igt9`, `27z3` | §2.6 visto bueno a las capturas (y `igt9` se mira de paso en B1) | pregunta 2 |
| `gulp` | §2.6 visto bueno al texto | pregunta 3 |
| `1qfi` | §2.6 visto bueno a las capturas (su hechaCuando lo pide) | pregunta 4 |
| `e7by`, `k2up` | §2.6 visto bueno al rediseño | pregunta 5 |
| `i00g` | §2.6 visto bueno y una pregunta abierta | pregunta 6 |
| `laik` | §2.8 decisión pendiente | — |
| `nmtk` | fuera de QA: su PR #650 no está en 2.2 (card `uvwn`) | — |
| `b4es`, `eukp` | de Lola (marketing), no las toqué | — |
