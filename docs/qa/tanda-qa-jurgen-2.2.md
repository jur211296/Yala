# Tanda de QA de Jürgen — 2.2

Barrido del 2026-10-18 con `/barrido-qa`, sobre `origin/2.2` en `71e444567` (#554), con el CI de 2.2 ya en verde en
Xcode 27.1 (PR #555). Las 15 cards de 2.1 que siguen «in qa» no entran aquí: son de la tanda de 2.1
(`tanda-qa-jurgen-2.1.md`), que lleva la sesión de QA guiado del TestFlight 17.

- **Revisado:** las 53 cards de 2.2 en «in qa» y sus PRs (#482 a #554), y los tickets de 2.2 en `tickets/qa/`.
- **Pasan a done:** 43 cards y 1 ticket, cada una con su evidencia en la nota de la card.
- **Probado en el simulador:** 1 prueba (importar un CSV con dos filas malas), en verde. Capturas en
  `~/Claude/worktrees/_capturas/2026-10-18-barrido-qa-2-2/importar-*.png`. Su PR la había dejado para el iPhone porque
  creía que el simulador no deja elegir un archivo; sí deja.
- **Se quedan para tu iPhone:** 10 cards, en 4 montajes. **Para aprobar con capturas:** 1 (el diseño de la tarjeta con
  varias divisas).
- **Tiempo total estimado: unos 75 min** de iPhone y 2 min de capturas. Nada de 2.2 bloquea el lanzamiento de 2.1.

Los ids de card van sin el prefijo `tablero-`. Cada prueba dice qué la retiene: §4 es «solo en un iPhone real» y §5 es
«tu visto bueno».

## Antes de empezar

1. **Build:** todo va con **Yala Dev compilado desde `2.2`** con Xcode 27.1, salvo las de Siri, que piden **iOS 27** en el
   iPhone. No medí si ya hay un TestFlight de 2.2; si lo hay, vale para todo.
2. **Siri en el idioma de la prueba**: Ajustes › Siri › Idioma.

## Qué bloquea el lanzamiento

Nada. 2.2 no tiene fecha de envío, y ninguna de estas pruebas pierde datos ni deja a un usuario nuevo sin entrar.

## Las pruebas, por montaje

### A · Un iPhone con Yala Dev (unos 25 min)

**A1 · Tarjeta con varias divisas, entrega 2** (`tarjeta-con-varias-divisas-entrega-2-la-17ec`) · §4 notificaciones + §5.
1. En una tarjeta de crédito con una línea en USD, pon el día de pago en hoy y espera el aviso: llega **uno**, no dos.
2. El diseño de la tarjeta lo apruebas con las capturas del lote (abajo).

**A2 · Tarjeta, entrega 3: Apple Pay** (`tarjeta-con-varias-divisas-entrega-3-se-i9rh`) · §4 Apple Pay.
1. Paga con Apple Pay en **$** usando esa tarjeta.
2. Abre la Bandeja: el borrador sale en la **línea USD** de la tarjeta.

**A3 · Tarjeta, entrega 4: Yala IA** (`tarjeta-con-varias-divisas-entrega-4-inf-dbxp`) · §4 App Attest.
1. En Yala IA pregunta «¿cuánto debo en mi tarjeta?».
2. Habla de **una** tarjeta y no suma soles con dólares.

**A4 · Recordatorio de un pago** (`ux-2-2-l10-13-tocar-un-recordatorio-abre-v5p0`) · §4 notificaciones.
1. Crea un pago que venza hoy con aviso.
2. Toca el recordatorio cuando llegue: abre el detalle de **ese** pago.
3. El monto del aviso sale como en la app («S/ 45.00» o «PEN 45.00», según tu preferencia).

**A5 · Aviso de pago de la tarjeta** (`ux-2-2-l10-14-el-aviso-de-pago-de-la-tar-nezl`) · §4 notificaciones.
1. En una tarjeta de crédito activa «Avisar en fecha de pago» con el día de pago en hoy.
2. Toca el aviso: abre la ficha de esa tarjeta en el Panel.

**A6 · App Attest** (`declarar-el-entitlement-de-app-attest-de-g8rc`) · §4 App Attest.
1. Desde Xcode, scheme **Yala** en Debug, en el iPhone.
2. Haz una pregunta a Yala IA: se contesta, sin error de sesión.

### B · Cuenta real en la nube, Apple, Google o iCloud (unos 25 min)

**B1 · Lote 5: primeros días** (`auditoria-ux-2-2-lote-5-primeros-dias-gu-k4gd`) · §4 inicio de sesión e iCloud reales.
Guion entero en el PR #538, bloque B:
1. Instalación limpia › «Empezar» › «Ya tengo una cuenta» › «Entrar con Apple»: sale el consentimiento en tres fichas,
   con «Entendido, entrar a mi cuenta», y luego la hoja de Apple. Cancelar vuelve a «¡Hola de nuevo!».
2. Con una cuenta en la nube, durante «Conectando con tu cuenta…» sale el porcentaje bajo la barra.
3. Con datos en tu iCloud: Restaurar desde iCloud › «Encontramos tus datos» es una lista con cada cifra una vez, y
   «Traer mis datos» los trae.

**B2 · Invitar al crear un grupo** (`ui-2-2-l12-10-al-guardar-un-grupo-no-se-i104`) · §4 cuenta en la nube real.
1. Crea un grupo de verdad.
2. En la hoja «“X” está listo», toca «Invitar por WhatsApp u otra app»: sale la hoja de compartir con el enlace.

### C · Dos teléfonos y compra sandbox (unos 10 min)

**C1 · Lote 5, terminar el onboarding en otro** (`auditoria-ux-2-2-lote-5-primeros-dias-gu-k4gd`) · §4 dos dispositivos.
1. Con el onboarding abierto en un teléfono, termínalo en el otro.
2. El primero se cierra con «Terminaste la configuración en tu otro dispositivo. Ya está todo aquí.».

**C2 · Lote 5, tour Pro** (misma card) · §4 compra sandbox.
1. Suscríbete en sandbox.
2. En el tour, la fase del Panel señala «Voz» y «Foto» y luego «IA». No aparece ningún «+» flotante.

### D · Siri en iOS 27 (unos 15 min)

**D1 · Siri con IA** (`integrar-yala-con-el-nuevo-siri-con-ia-d-egjm`) · §4 Siri por voz.
1. Abre Yala una vez.
2. Desbloqueado: «Oye Siri, ¿cuánto gasté en Yala?» → lo de este mes (lo mismo que el widget de gastos).
3. «Oye Siri, ¿cuánto tengo en Yala?» → el total (lo mismo que el widget de saldo).
4. Bloqueado, repite el 3: pide desbloquear.
5. «Oye Siri, abre mi cuenta <nombre> en Yala» → abre su ficha.

**D2 · Frases de Siri en portugués** (`las-frases-de-siri-que-la-app-ensena-en-eol6`) · §4 Siri por voz.
1. Ajustes › Idioma: Português (Brasil) primero; Siri en Português (Brasil). Abre Yala una vez.
2. «Oi Siri, Anota uma despesa no Yala» → pregunta qué registrar.
3. «Oi Siri, Registre no Yala» → abre Nuevo registro.
4. Vuelve a español.

## Para aprobar con capturas

| Card | Qué miras | Capturas |
|---|---|---|
| `tarjeta-con-varias-divisas-entrega-2-la-17ec` | La tarjeta con una fila por línea y «Total ≈» en el Panel, y el selector de línea en la ficha | `~/Claude/entregas/Yala--tarjeta-varias-divisas-entrega-2/capturas/despues-1-panel.png`, `despues-2-ficha.png`, `despues-2b-ficha-linea-usd.png` |

## Lo que pasó a done

| Card / ticket | Motivo | Evidencia |
|---|---|---|
| `auditoria-ux-2-2-lote-1-primera-vez-bien-j3b2` | Sus bugs pasan a done y las mejoras están implementadas | ver B1 y B2 del lote 1 |
| `auditoria-ux-2-2-lote-2-apuntar-un-movim-likq` | Sus 8 bugs pasan a done | ver lote 2 |
| `auditoria-ux-2-2-lote-6-primera-vez-con-z12j` | Bugs a done; L6-4/5/6 implementadas (PR #538) | ver lote 6 |
| `bug-lote-1-b1-…-9dn7` | Ya hay evidencia | XCUITest `LanguageSelectionUITests` + capturas del lote 1 |
| `bug-lote-1-b2-…-a6w0` | Ya hay evidencia | capturas `1.9-paso7` ANTES/ARREGLO |
| `bug-lote-2-b1/b4/b5` (`bsi8`, `ui6p`, `0hnh`) | Ya hay evidencia | capturas `*-ANTES-B*`/`*-DESPUES-B*` del lote 2 |
| `bug-lote-2-b2/b7` (`q1ze`, `he9b`) | Ya hay evidencia | XCUITest `NewTransactionTypeSelectorUITests` + capturas |
| `bug-lote-2-b6-…-u755` | Ya hay evidencia | tests del PR #483 + capturas |
| `bug-lote-3-b1…b4` (`cr5n`, `0kbp`, `ddhd`, `3lfo`) | Ya hay evidencia | antes/después del PR #492 + `AxisLabelFormatTests`, `PanelTotalAccountsLogicTests`, `LiveAnchorEducationLogicTests` |
| `bug-lote-5-b1…b7` (7 cards) | Ya hay evidencia | antes/después en `_capturas/2026-10-14-auditoria-ux-2-2-lote-5-primeros-dias/` + tests del PR #494 |
| `bug-lote-6-b4-…-4kjn` | Accesibilidad, criterio de Jürgen | contraste 6,4:1 medido |
| `bug-lote-6-b1/b2/b3/b5` (4 cards) | Ya hay evidencia | capturas del PR #495 + 20 XCUITest del Welcome |
| `ux-2-2-l1ui-1…8` (8 cards) | Ya hay evidencia | variante elegida sobre capturas reales, implementada en el PR #491; antes/después por XCUITest |
| `ux-2-2-pantalla-de-carga-…-p45n`, `l1-3-…-gtxa`, `reabre-yala-…-ufib` | Ya hay evidencia | PR #485, recorrido en el simulador con capturas |
| `ux-2-2-la-oferta-de-prueba-pro-…-e63v` | Ya hay evidencia | XCUITest `TrialOfferMomentUITests` con mutante |
| `ux-2-2-l4-5-…-9jfk` | Ya hay evidencia | XCUITest `InboxCrudUITests` con mutante + capturas |
| `ui-2-2-l13-2-…-5a6x` | Ya hay evidencia | `UXAudit22Lote12y13UITests` + `despues-4-saldos.png` |
| `con-el-iphone-en-espanol-…-ymwo` + ticket `siri-shortcut-error-replies-speak-english-on-a-spanish-iphone` | Ya hay evidencia | el simulador es-PE reproducía el inglés y da español tras el #552 |
| `yala-ia-en-la-nube-textos-…-gic9` | Ya hay evidencia | `YalaIACloudExploreConsentUITests` + textos P1/N1 contra el doc en 16 idiomas + capturas |

## Lo que se queda

| Card | Lo retiene |
|---|---|
| `tarjeta-con-varias-divisas-entrega-2-la-17ec` | §4 notificaciones (aviso del día de pago) y §5 diseño |
| `tarjeta-con-varias-divisas-entrega-3-se-i9rh` | §4 Apple Pay |
| `tarjeta-con-varias-divisas-entrega-4-inf-dbxp` | §4 App Attest (Yala IA real) |
| `ux-2-2-l10-13-tocar-un-recordatorio-abre-v5p0` | §4 notificaciones |
| `ux-2-2-l10-14-el-aviso-de-pago-de-la-tar-nezl` | §4 notificaciones |
| `declarar-el-entitlement-de-app-attest-de-g8rc` | §4 App Attest |
| `auditoria-ux-2-2-lote-5-primeros-dias-gu-k4gd` | §4 inicio de sesión e iCloud reales, dos dispositivos, compra sandbox |
| `ui-2-2-l12-10-al-guardar-un-grupo-no-se-i104` | §4 cuenta en la nube real |
| `integrar-yala-con-el-nuevo-siri-con-ia-d-egjm` | §4 Siri por voz |
| `las-frases-de-siri-que-la-app-ensena-en-eol6` | §4 Siri por voz |
