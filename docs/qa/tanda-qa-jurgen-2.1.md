# Tanda de QA de Jürgen — 2.1

Barrido del 2026-10-15 con `/barrido-qa`, sobre `origin/2.1` en `8cd693cb6` (#513). Sustituye al del 12-oct y recoge lo
que quedó del QA guiado del 14-15 oct (pasaron 8 de 31).

- **Revisado:** las 23 cards de 2.1 (21 «in qa» y 2 «blocked»), los 41 tickets de `tickets/qa/` y los 2 de
  `tickets/blocked/`, los PRs #474 a #513 y las 23 pruebas que el QA guiado dejó pendientes.
- **Pasan a done:** 6 cards y 16 tickets. Cinco de esos tickets ya habían pasado en el QA guiado y solo faltaba
  moverlos. Un ticket vuelve a backlog (F1).
- **Probado en el simulador:** 12 pruebas, todas con la evidencia en `~/Claude/worktrees/_capturas/2026-10-15-barrido-qa-2-1/`.
  Una falló y tiene card de bug (C5).
- **Se quedan para tu iPhone:** 18 pruebas en 4 bloques. **Sin iPhone:** 5. **Para aprobar con capturas:** 7 pantallas.
- **Tiempo total estimado: unas 6 h 40 min** (iPhone 5 h 35 min, sin iPhone 55 min, capturas 10 min). Lo que bloquea
  el lanzamiento suma **2 h 35 min**.

Los ids de card van sin el prefijo `tablero-`. Cada prueba dice qué la retiene: §4 es «solo en un iPhone real» y §5 es
«tu visto bueno».

## Antes de empezar

1. **Builds.** El TestFlight 16 (`7ac7d21a6`, #476) no lleva #427, #490, #501 ni #512. El bloque A va con **Yala Dev
   compilado desde `2.1`** (`8cd693cb6` o posterior). Si subes un TestFlight 17 desde ese `2.1`, vale para todo.
2. **D2 empieza con el build anterior:** en ese iPhone no borres Yala antes de C · D2.
3. **A · App Attest instala el scheme «Yala» desde Xcode** y sustituye a la Yala de TestFlight de ese iPhone. Hazla la
   última del día, o en un iPhone sin la Yala de TestFlight.
4. **Archivos de prueba** en `~/Claude/entregas/qa-guiado-2-1/`: fotos en `1-para-Fotos/` y, en `2-para-Archivos/`,
   el CSV de 1.500 movimientos para A · C1. Pásalos por AirDrop.

## Qué bloquea el lanzamiento

Si una falla, 2.1 no sale: se pierden datos, un usuario nuevo no puede entrar o Apple rechaza el envío.

| # | Prueba | Card / ticket | Min |
|---|---|---|---|
| 1 | E · G1 · Etiquetas de App Privacy | `el-manifiesto-de-privacidad-no-declara-l-kgqv` | 15 |
| 2 | E · G2 · La ficha cuenta la nube | `la-web-la-politica-y-la-ficha-dicen-que-i6tj` | 5 |
| 3 | E · G3 · Checklist de envío | `checklist-de-envio-de-2-1-a-app-store-ve-d0ui` | 15 |
| 4 | A · C1 · Activar la nube con muchos movimientos | `snapshot-upload-has-no-ceiling-and-no-way-out` | 20 |
| 5 | C · D1 · «Primera vez › privado» mira iCloud | `welcome-private-fresh-start-skips-icloud-check` | 20 |
| 6 | C · D2 · Actualizar encima no cierra la sesión | `previous-person-cloud-session-survives-…` | 10 |
| 7 | C · D3 · «Vengo por un grupo» con datos de iCloud | `groups-entry-on-a-mirrored-store-…` (2 tickets) | 40 |
| 8 | D · E1 · Unirse a un grupo con dos iPhone | `validar-en-testflight-unirse-a-un-grupo-e1ah` | 30 |

**Orden:** E · G1-G3 primero (no piden iPhone y Apple los mira al enviar). Luego los bloques en orden A, B, C y D.

---

## A. iPhone de QA con Yala Dev contra staging — 1 h 30 min

### A · vb1f — Entrar con Google cuando este iPhone ya tiene cuenta con Apple (parte C) · 5 min · §4 inicio de sesión real
Card `entrar-con-google-cuando-este-iphone-ya-vb1f`. La parte A (Apple primero con su nota) ya pasó en el simulador.
Montaje: el Apple ID del iPhone con una cuenta de Yala creada con Apple, y una cuenta de Google **sin** cuenta en Yala.
1. Borra Yala Dev y vuelve a instalarla. «Empezar» › «Ya tengo una cuenta».
2. «Entrar con Google» › consentimiento › la cuenta de Google sin Yala → «Esa cuenta usa otro método».
3. Toca **«Crear cuenta con Google»** → consentimiento. **No** debe volver a salir la hoja de Google, y sigue al
   onboarding. Si vuelve a salir, avisa a Frank: el servidor rechazó la credencial reusada.

### A · C6 — El consentimiento de Grupos queda registrado · 15 min · §4 inicio de sesión real
Ticket `groups-consent-door-spec`.
1. Instalación fresca con una cuenta Apple o Google de pruebas: «Vengo por un grupo» › «Crear mi primer grupo» →
   explicación › entrar › «Grupos en la nube» › «¿Cómo te llamas?».
2. «Aceptar y continuar», pon tu nombre y crea un grupo.
3. Avisa a Frank: comprueba en staging que hay **una** fila de consentimiento de esa cuenta.
4. Perfil › «Cerrar sesión» y vuelve a entrar por «Vengo por un grupo» con la misma cuenta → no vuelve a salir «Grupos
   en la nube», y sigue habiendo una sola fila.

### A · C1 — Activar la nube con muchos movimientos · 20 min (casi todo espera) · **bloquea** · §4 sesión real e iCloud
Ticket `snapshot-upload-has-no-ceiling-and-no-way-out`. Los techos, el modo avión al 55 % y «Cancelar la activación» ya
los fijan los tests (22 mutantes). Lo único que falta es ver que el techo no salta en una subida larga de verdad.
Montaje: Yala Dev en modo privado con datos y una cuenta de staging **nueva** (no la Google A, que ya volvió a iCloud).
1. Perfil › «Importar archivo» › `movimientos-qa-1500.csv`.
2. Perfil › «Dónde viven tus datos» › «Migrar a la nube» › consentimiento › entra con la cuenta nueva.
3. No toques nada: la barra avanza (22, 35, 55, 75 y 80 %) sin quedarse parada y acaba pidiendo cerrar y volver a abrir
   Yala.
4. Reabre → el modo nube está activo y los 1.500 movimientos siguen ahí.

### A · C4 — Tras volver a iCloud, un movimiento creado en la nube conserva su cuenta · 20 min · §4 CloudKit real
Card `tras-volver-a-icloud-un-movimiento-cread-amad`, ticket `cloud-tx-epoch-orphan-relations`. Va justo después de
A · C1, con esa misma cuenta ya en la nube. Con el iPhone por cable, la Consola del Mac filtrando «danglingRef».
1. Crea «QA rápida 1» y «QA rápida 2» con cuenta y subcategoría.
2. Antes de 5 min: Perfil › «Dónde viven tus datos» › «Volver a iCloud» y reabre cuando lo pida → en Registros, los dos
   conservan cuenta y subcategoría, también tras reabrir.
3. Apunta si la Consola mostró «danglingRef». Si se pierde algo, avisa: el ticket sube a very-high.

### A · App Attest — El build de Xcode de «Yala» consigue sesión de IA · 5 min · §4 App Attest
Card `declarar-el-entitlement-de-app-attest-de-g8rc`, ticket `release-plist-leftovers-widget-build-faceid-appattest`.
Ver el punto 3 de «Antes de empezar».
1. Xcode › scheme **Yala** (no Yala Dev), Debug, en el iPhone.
2. Haz una pregunta a Yala IA → responde. Antes daba 401.

---

## B. Cámara y micrófono, con Pro — 23 min

Sirve el TestFlight 16 o Yala Dev. El simulador no tiene cámara, y en la Mac sin micrófono no se puede dictar. Todo lo
demás de estas pantallas pasó en el simulador.

### B · cámara — Registro por foto con la cámara · 5 min · §4 cámara
Card `mejorar-el-registro-por-imagen-de-punta-g5wl`, ticket `image-entry-end-to-end-redesign`.
1. Panel › botón de imagen › «Cámara» (la primera vez acepta el permiso) y fotografía un recibo → «Leyendo tu foto…» y
   luego «Esto leí».
2. Ajustes de iOS › Yala › Cámara apagada. Vuelve y toca «Cámara» → «Yala no puede usar la cámara» con «Abrir
   Configuración». Vuelve a encenderla.

### B · voz — Registro por voz de punta a punta · 8 min · §4 micrófono
Card `mejorar-el-registro-por-voz-de-punta-a-p-u58k`, ticket `voice-entry-end-to-end`.
1. Panel › icono de onda (Voz) → la hoja ya escucha (la primera vez iOS pide el micrófono). Habla normal y luego fuerte:
   el halo crece con la voz.
2. Con música en otra app, abre Voz y toca «Cancelar» → la música vuelve a sonar.
3. Voz › di «taxi 12 y café 8» › «Listo» → dos filas y «Guardar 2» registra las dos.
4. Con modo avión, toca Voz → «Sin conexión» con «Usar imagen» y «Volver a grabar». Quita el modo avión.

### B · idioma de voz — La voz en otros idiomas · 6 min · §4 micrófono
Card `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f`, ticket `ai-every-call-sends-its-task-and-passes-the-bench`.
1. Perfil › Personalización › «Idioma de voz» → «Idioma de la app» y los 10 idiomas.
2. Dicta «Ayer 25 soles con 50 en <tu comercio habitual>» → 25,50 y el comercio bien escrito.
3. Elige English y dicta «Coffee 4.50 at Starbucks» → borrador de 4,50. Vuelve a «Idioma de la app».

### B · dictado del chat — Dictar en Yala IA · 4 min · §4 micrófono
Card `mejorar-el-diseno-del-dictado-en-yala-ai-apsc`, ticket `chat-dictation-looks-poor`.
1. Yala IA › micro → «Escuchando…». Habla: el halo crece con la voz.
2. Con música en otra app, «Cancelar» → la caja vuelve vacía y la música vuelve a sonar.
3. Micro › di «gasté 25 en el almuerzo con la tarjeta» › «Listo» → el texto queda en la caja, sin enviarse.

---

## C. TestFlight con tu Apple ID — 2 h 35 min

Un iPhone de pruebas con tu Apple ID: estas pruebas leen tus datos reales de iCloud y solo TestFlight ve ese contenedor.
Ninguna borra iCloud salvo que lo elijas. Todas son §4 (iCloud real; D2, además, actualizar encima).

### C · D1 — «Primera vez › privado» mira iCloud antes de empezar · 20 min · **bloquea**
Ticket `welcome-private-fresh-start-skips-icloud-check`. Sin iCloud ya pasó en el simulador: «No pudimos revisar tu
iCloud» › «Seguir así» › reabrir › onboarding.
1. Apunta cuántos movimientos y cuentas tienes, y el mes del más antiguo. Desinstala e instala Yala.
2. «Es mi primera vez» › «Tu cuenta en tu iCloud privado» → «Revisando qué hay en tu iCloud…» y luego un aviso con
   cifras que casan con lo apuntado.
3. Si en cambio sale siempre «No pudimos conectarnos a iCloud», para: es el fallo que bloquearía a todo usuario nuevo.
4. Toca volver → regresas a la elección. Entra otra vez por privado → mismas cifras; «Traer mis datos».

### C · D2 — Actualizar encima no cierra la sesión · 10 min · **bloquea**
Ticket `previous-person-cloud-session-survives-fresh-start-and-reinstall`.
1. Con el build anterior, entra con una cuenta de nube de prueba y crea un grupo → Perfil › «Dónde viven tus datos»
   muestra su correo.
2. Instala el build nuevo **encima**, sin borrar → la sesión sigue abierta y Grupos entra sin pedir nada.
3. Borra Yala y reinstala → la bienvenida de instalación nueva; «Ya tengo una cuenta» pide elegir y no entra solo.
4. Entra con la cuenta de prueba → recupera sus grupos.

### C · D3 — «Vengo por un grupo» en un teléfono con tus datos de iCloud · 40 min · **bloquea**
Tickets `groups-entry-on-a-mirrored-store-still-blocks-the-owner` y `groups-only-second-launch-mounts-icloud-mirror`.
1. Borra Yala, reinstala, «Primera vez» › iCloud privado › «Traer mis datos» y deja que baje. Cierra Yala del todo.
2. Vuelve a la bienvenida › «Vengo por un grupo» › «Crear mi primer grupo» → nada de «Aquí ya hay datos guardados»; sale
   «Estamos subiendo tus últimos cambios a iCloud…» y te pide reabrir.
3. Reabre → la puerta de Grupos y el inicio de sesión sin elegir de nuevo; crea el grupo. Cierra y abre tres veces → solo
   Grupos; nada de tus cuentas ni movimientos de iCloud.
4. Cierra la sesión de Grupos y reabre → nada del histórico.
5. Reinstala › «Ya tengo una cuenta» › «Restaurar desde iCloud» → vuelve **todo** el histórico. Vacío es fallo grave.

### C · D4 — Cerrar la sesión privada no pierde lo que no subió · 35 min
Ticket `session-exits-one-verb-per-session`.
1. En la sesión privada, crea un gasto, espera 10 s y Perfil › «Cerrar sesión» → cierra sin aviso.
2. «Ya tengo una cuenta» › «Restaurar desde iCloud» → todos tus datos, incluido ese gasto.
3. Modo avión, crea un gasto y cierra sesión → «Guardando tus cambios…» y, a los 45 s, un aviso con «1».
4. «Esperar» y quita el modo avión → cierra sola.
5. Repite el paso 3 y fuerza el cierre de Yala durante la espera → al reabrir, la sesión y los datos siguen ahí.

### C · D5 — «Activar Yala completo» pregunta dónde guardar tus finanzas · 30 min
Ticket `full-mode-activation-must-ask-where-personal-data-lives`.
1. Reinstala › «Vengo por un grupo» › crea un grupo y apunta un gasto tuyo y otro del otro miembro.
2. Perfil › «Activar Yala completo» → «¿Dónde guardamos tus finanzas?» con dos tarjetas.
3. «Tu cuenta en tu iCloud privado» → aviso con cifras y tres botones (restaurar, borrar, cancelar).
4. «Traer mis datos» › reabre › «Continuar» → tus datos de antes, con tu nombre y tu divisa.
5. Registros → cada gasto de grupo aparece una sola vez.

### C · D6 — «Empezar desde cero» en Restaurar · 20 min
Ticket `restore-start-fresh-keeps-the-imported-corpus`.
1. Apunta tus cifras de iCloud; desinstala e instala.
2. «Ya tengo una cuenta» › «Restaurar desde iCloud» › «Empezar desde cero» › confirmar → sale una puerta con cifras que
   casan y tres salidas, no el onboarding.
3. «Traer mis datos» › «Continuar» → los datos vuelven completos.
4. Cierra y reabre un par de veces → siguen ahí.

---

## D. Dos iPhone — 1 h 5 min

E2 y E3 piden la misma cuenta en los dos. E1 pide dos cuentas distintas y los dos con el build de TestFlight: un build
de Xcode da 401 contra producción. Las tres son §4 (dos dispositivos físicos).

### D · E1 — Unirse a un grupo por enlace · 30 min · **bloquea**
Card `validar-en-testflight-unirse-a-un-grupo-e1ah` (blocked), ticket `tickets/blocked/groups-join-intent-reconciler.md`.
1. iPhone A, tu cuenta: crea el grupo «QA unión» y comparte su enlace de invitación con el iPhone B.
2. iPhone B, instalación nueva con otra cuenta de Apple o Google: abre el enlace › «Unirme» › entra. Debe decir
   «Conectando con tu grupo…» y luego «Esperando aprobación», nunca «¡Todo listo!» de golpe.
3. iPhone A: llega «X quiere unirse» y la solicitud está en el detalle del grupo. Aprueba.
4. iPhone B: el grupo se abre solo. Apunta un gasto de 30 → en el iPhone A aparece en menos de un minuto, con el saldo
   correcto. B no recibe ningún aviso de «se unió».
5. Repite con un grupo nuevo y, en el paso 2, cierra Yala del todo en B antes de que aparezca el grupo. Reábrela → la
   unión se completa sola y a A le llega la solicitud.

### D · E2 — Reintentar «Volver a iCloud» en el segundo iPhone · 20 min
Card `en-el-segundo-dispositivo-de-una-cuenta-gk5w`, ticket `reverse-exit-on-a-reverted-account-rejects-the-retry`.
1. Dos iPhone con la misma cuenta en la nube, los dos en modo nube.
2. En el primero, Perfil › «Dónde viven tus datos» › «Volver a iCloud» hasta terminar.
3. En el segundo, «Volver a iCloud» → sale la espera; cancélala.
4. Reintenta en el segundo → avanza. No debe salir «tu cuenta no lo permitía».

### D · E3 — Un ajuste viaja al otro iPhone · 15 min
Card `las-preferencias-se-volvian-a-guardar-so-d44s` (blocked), ticket `tickets/blocked/apppreferences-rewritten-on-launch.md`.
1. iPhone A: Perfil › Personalización › activa «Solo gastos». A los pocos minutos, el iPhone B lo tiene activado.
2. iPhone A: concede el permiso de notificaciones desde el primer aviso → en el B, las alertas de presupuesto salen
   activadas.
3. Cierra Yala en el A. En el B, cambia la divisa principal. Abre el A → tiene la divisa nueva; abrirlo no la pisa.

---

## E. Sin iPhone: App Store Connect, la ficha y las claves — 55 min

### E · G1 — Etiquetas de App Privacy · 15 min · **bloquea**
Card `el-manifiesto-de-privacidad-no-declara-l-kgqv`.
1. Decide si fotos y audio van como vinculados al usuario (lo prudente) o no vinculados.
2. App Store Connect › App Privacy: copia la tabla del PR #446.
3. Xcode › Organizer › Privacy Report del archivo de 2.1, y compáralo con la tabla. Deben coincidir.

### E · G2 — La ficha cuenta la nube · 5 min · **bloquea**
Card `la-web-la-politica-y-la-ficha-dicen-que-i6tj`, ticket `session-redesign-web-and-store-copy`. La política y los
términos ya están (#469).
1. Pregunta a Lola si la ficha de los 7 idiomas ya dice que Grupos vive en la nube y si cambió la rama de producción de
   Vercel de `1.0` a `2.1`.
2. Con G1 hecho y la ficha al día, la card pasa a done.

### E · G3 — Checklist de envío · 15 min · **bloquea**
Card `checklist-de-envio-de-2-1-a-app-store-ve-d0ui`.
1. Abre `docs/RELEASE-CHECKLIST-2.1.md` y marca lo que ya está: la política (#469), el manifiesto (#446), los plist
   (#447) y el esquema de CloudKit.
2. Repasa las casillas de fuera del repo: la app de Google en «Prueba», la URL de App Store Server Notifications y la
   rama de producción de Vercel.
3. Lo que siga sin marcar es lo que te queda antes de enviar.

### E · G4 — Claves del gateway · 10 min
Card `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f`.
1. Revoca la clave vieja de OpenAI.
2. Mira la caducidad de las claves gateway-staging y gateway-production.
3. Pasa a 1Password `~/Secrets/yala-gateway/{openai-staging.key, openai-prod.key, staging-dev-shared-secret}`.

### E · capturas de la ficha — Subir el set B a App Store Connect · 10 min
Card `elegir-la-direccion-de-las-capturas-app-sp9y`. Elegiste B; el set está en
`~/Claude/propuestas/capturas-app-store-final-2026-10-13/`. Súbelo a la versión 2.1 (o pídeselo a Lola).

---

## Para aprobar con capturas, sin iPhone — 10 min

Pantallas nuevas que ya funcionan en el simulador y que no has visto construidas. Si alguna no te convence, dilo y sale
un ticket de pulido; si te convencen, sus cards pasan a done. Todas en
`~/Claude/worktrees/_capturas/2026-10-15-barrido-qa-2-1/`.

| Pantalla | Card | Capturas |
|---|---|---|
| Eliminar una cuenta con movimientos: mover o borrar | `al-eliminar-una-cuenta-sus-movimientos-q-ofst` | `ofst-1…7` |
| «¡Hola de nuevo!» con Apple primero y «La que usaste en este iPhone» | `entrar-con-google-cuando-este-iphone-ya-vb1f` | `vb1f-1` |
| Tarjetas de registro en Yala IA | `mejorar-cards-de-registros-nuevos-en-yal-rdfd` | `b4-2…4` |
| Yala IA como app de mensajería (saludo y preguntas) | ticket `ai-chat-reads-heavier-than-a-messaging-app` | `b4-1` |
| Panel de dictado del chat | `mejorar-el-diseno-del-dictado-en-yala-ai-apsc` | `b4-5` |
| Hoja de voz y «Entendí 2 registros» | `mejorar-el-registro-por-voz-de-punta-a-p-u58k` | `u58k-1`, `u58k-2` |
| Registro por foto: hoja, lectura, guardado y fallo | `mejorar-el-registro-por-imagen-de-punta-g5wl` | `b1-1…5`, `g5wl-1`, `g5wl-2` |

---

## Fuera de la tanda

| Qué | Por qué | Quién |
|---|---|---|
| C5 · «Borrar todo y continuar» con cambios de grupos (card `decidir-tras-cancelar-la-entrada-con-la-069g`) | En el simulador, en vez de la oferta de perder los cambios sale «No pudimos borrar todo». Sin el cambio pendiente sí llega al onboarding. Card de bug `tras-salir-de-la-nube-borrar-todo-y-cont-8xt4` (high). No la corras hasta que se aclare. | Frank |
| F1 · PDF con contraseña en el iPad (`ipad-locked-pdf-password-may-crash-on-open`) | Caso raro que no pierde datos; el cierre visto es de `UIFocusSystem` con teclado físico en el simulador. Vuelve a backlog con la card `receiptdropuitests-test-lockedpdf-falla-pbwh`. | Frank |
| Las 41 cards «in qa» de 2.2 y `rpoy` (reels) | No son de 2.1; `rpoy` es de Lola. | — |

---

## Lo que pasó a done

### Cards

| Card | Motivo | Evidencia |
|---|---|---|
| `el-delegado-de-notificaciones-se-asigna-bdxj` | Se puede probar en el simulador | Con Yala cerrada del todo, el toque en un aviso de presupuesto abre Presupuestos y el resumen real de pagos abre Pagos planificados. Capturas `a4-1…4`. |
| `decidir-el-aviso-no-pudimos-cerrar-tu-se-7m1e` | Se puede probar en el simulador; la card decía «si no sale, se descarta» | Desasociar con un cambio de grupos sin subir muestra su propio aviso y, en Perfil, 15 s sin «No pudimos cerrar tu sesión». Capturas `a6-1…3`. |
| `tras-vaciar-los-datos-desde-otro-disposi-pb6r` | Se puede probar en el simulador | El widget Balance en solo grupos invita a «Activar Yala completo», el toque abre la activación y luego deja de invitar. Capturas `c7-1…4`. |
| `al-compartir-una-imagen-a-yala-la-lectur-nxle` | Simulador con la extensión real + XCUITest | Fotos › Compartir › Yala Dev arranca «Leyendo tus fotos…» hasta «Guardar 3»; el resto de casos, `SharedImageEntryUITests`. Capturas `b2-1`, `b2-2`. |
| `un-estado-de-cuenta-en-pdf-solo-se-lee-e-4j2s` | Simulador con lectura real de staging | 3 páginas → 36 movimientos sin saldos ni subtotales; contraseña mala y buena. Capturas `b1-6…9` y `b1-6c-pdf-36-filas.txt`. |
| `yala-no-aparece-al-compartir-varias-capt-3ut5` | Simulador con la extensión real; las 10 fotos grandes, por el código | 3 fotos → «Guardar 3» y Bandeja; 12 → 10 leídas y «Quedaron 2 fotos sin leer». Capturas `b2-1…5`. |

Ya estaban en done tras el QA guiado: `v5k7`, `yneu`, `r6pd`, `5sr2` y `ni6g`.

### Tickets

| Ticket | Motivo | Evidencia |
|---|---|---|
| `account-currency-change-leaves-scheduled-and-favorites-stale` | Pasó en el QA guiado (A1) | Tu iPhone de QA, 15-oct |
| `changing-an-account-currency-orphans-its-whole-history` | Pasó en el QA guiado (A1 paso 4) | Tu iPhone de QA, 15-oct |
| `inbox-dismiss-x-does-not-delete-the-draft-for-good` | Parte A en el QA guiado (A3); B y C, tests de dos dispositivos | `InboxDismissScheduledDraftTests`, `InboxDismissScheduledDraftCloudTests` |
| `cashflow-scheduled-line-ignores-payment-currency` | Pasó en el QA guiado (A5) | Tu iPhone de QA, 15-oct |
| `settings-redesign-as-grouped-lists-like-ios` | Pasó en el QA guiado (A7); el iPad es maquetación | Tu iPhone de QA, 15-oct |
| `notification-delegate-assigned-after-launch` | Simulador | Capturas `a4-1…4` |
| `scheduled-payments-notif-dedup` | Simulador (fase 2); fases 3 y 4 por test | Resumen a las 15:31:00 con Yala cerrada, una vez; `ScheduledPaymentNotificationGateLogicTests` |
| `reverse-cutover-cerrado-para-cuentas-born-cloud` | QA guiado + código: la vuelta solo termina con las filas ya en CloudKit | `reverseUploadStatus() == .drained` en `MigrationRunner` |
| `cloud-sign-in-discovers-account-kind` | QA guiado (pasos 1, 2 y 4) + tests del paso 3 | `account.kind.test.ts`, goldens de staging, `CloudIdentityRoutingLogicTests`, `CloudIdentityDiscoveryTests` |
| `forward-migration-steps-have-no-ceiling-and-no-exit` | Fallo inyectado, fijado por tests con mutantes | `MigrationRunnerTests` §15 (22 mutantes), `ForwardStepCeilingLogicTests` |
| `step-flows-should-match-the-sep15-reference` | Simulador + XCUITest (Face ID) | Capturas `a8-1…7`; `StepGuideUITests` |
| `after-session-redesign-review-widgets-siri-applepay-and-web-copy` | Simulador (C7) + test (vaciado remoto) | Capturas `c7-1…4`; `RemoteWipeSharedSurfacesTests` |
| `pdf-statement-reads-only-the-first-page` | Simulador, lectura real | Capturas `b1-6…9` |
| `share-image-reading-does-not-always-start` | Simulador, extensión real + XCUITest | Capturas `b2-1`, `b2-2`; `SharedImageEntryUITests` |
| `sharing-several-photos-hides-yala` | Simulador, extensión real + código | Capturas `b2-1…5` |
| `vision-reads-every-dollar-sign-as-usd` | Simulador (PEN) + test (MXN) | Captura `b3-1`; `VisionCurrencySession2Tests` |

### PRs desde el barrido del 12-oct que no te piden nada

| PR | Por qué no |
|---|---|
| #490 | Dos avisos en cola salen uno detrás de otro. `ContentViewReadinessReleaseWiringTests` y dos XCUITest de enrutado. |
| #512 | Eliminar cuenta con movimientos: probado en el simulador, mover a otra divisa y borrar. Solo falta tu visto bueno a la hoja. |
| #427 | «Crear otra cuenta» que cae en una existente lo dice: pasó en el QA guiado (C2 paso 2). |
| #476, #501 | Sus restos están en la tanda: A · App Attest y A · vb1f. |
| #474, #477-#480, #484, #486, #487, #513 | Semillas, TestFlight 16, marketing, encargos y las skills de QA: no cambian la app publicada. |

## Lo que se queda

| Card / ticket | Prueba | Qué lo retiene |
|---|---|---|
| `entrar-con-google-cuando-este-iphone-ya-vb1f` | A · vb1f + capturas | §4 inicio de sesión real con Google; §5 la pantalla nueva |
| `groups-consent-door-spec` | A · C6 | §4 inicio de sesión real y la fila en staging |
| `snapshot-upload-has-no-ceiling-and-no-way-out` | A · C1 | §4 sesión real e iCloud |
| `tras-volver-a-icloud-un-movimiento-cread-amad` · `cloud-tx-epoch-orphan-relations` | A · C4 | §4 CloudKit real |
| `declarar-el-entitlement-de-app-attest-de-g8rc` · `release-plist-leftovers-widget-build-faceid-appattest` | A · App Attest | §4 App Attest |
| `mejorar-el-registro-por-imagen-de-punta-g5wl` · `image-entry-end-to-end-redesign` | B · cámara + capturas | §4 cámara; §5 la pantalla nueva |
| `mejorar-el-registro-por-voz-de-punta-a-p-u58k` · `voice-entry-end-to-end` | B · voz + capturas | §4 micrófono; §5 la pantalla nueva |
| `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f` · `ai-every-call-sends-its-task-and-passes-the-bench` | B · idioma de voz y E · G4 | §4 micrófono; las claves, sin iPhone |
| `mejorar-el-diseno-del-dictado-en-yala-ai-apsc` · `chat-dictation-looks-poor` | B · dictado del chat + capturas | §4 micrófono; §5 la pantalla nueva |
| `welcome-private-fresh-start-skips-icloud-check` | C · D1 | §4 iCloud real |
| `previous-person-cloud-session-survives-fresh-start-and-reinstall` | C · D2 | §4 actualizar encima de TestFlight |
| `groups-entry-on-a-mirrored-store-still-blocks-the-owner` · `groups-only-second-launch-mounts-icloud-mirror` | C · D3 | §4 iCloud real |
| `session-exits-one-verb-per-session` | C · D4 | §4 iCloud real |
| `full-mode-activation-must-ask-where-personal-data-lives` | C · D5 | §4 iCloud real y sesión real |
| `restore-start-fresh-keeps-the-imported-corpus` | C · D6 | §4 iCloud real |
| `validar-en-testflight-unirse-a-un-grupo-e1ah` · `groups-join-intent-reconciler` | D · E1 | §4 dos dispositivos |
| `en-el-segundo-dispositivo-de-una-cuenta-gk5w` · `reverse-exit-on-a-reverted-account-rejects-the-retry` | D · E2 | §4 dos dispositivos |
| `las-preferencias-se-volvian-a-guardar-so-d44s` · `apppreferences-rewritten-on-launch` | D · E3 | §4 dos dispositivos |
| `el-manifiesto-de-privacidad-no-declara-l-kgqv` | E · G1 | §4 App Store Connect |
| `la-web-la-politica-y-la-ficha-dicen-que-i6tj` · `session-redesign-web-and-store-copy` | E · G2 | §4 la ficha (Lola) |
| `checklist-de-envio-de-2-1-a-app-store-ve-d0ui` | E · G3 | §4 App Store Connect |
| `elegir-la-direccion-de-las-capturas-app-sp9y` | E · capturas de la ficha | §4 App Store Connect |
| `al-eliminar-una-cuenta-sus-movimientos-q-ofst` | Capturas | §5 la pantalla nueva |
| `mejorar-cards-de-registros-nuevos-en-yal-rdfd` · `chat-draft-card-redesign` | Capturas | §5 la pantalla nueva |
| `ai-chat-reads-heavier-than-a-messaging-app` | Capturas | §5 la pantalla nueva |
| `decidir-tras-cancelar-la-entrada-con-la-069g` · `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes` | Fuera, hasta el bug `8xt4` | Falló en el simulador |

## Encontrado en el barrido

- **`fresh-start-after-adopt-exit-with-group-changes-ends-in-device-wipe-failed`** (high, card `8xt4`): el caso de C5, arriba.
- **`inbox-alert-scheduled-count-has-no-singular`** (low): «Se añadieron 1 pagos planificados a tu bandeja».
- **`tutorial-completion-check-appears-only-after-reentering`** (low): tras «Listo», el ✓ del tutorial no sale hasta
  volver a entrar en Tutoriales.
- Del entorno: hasta reiniciar el simulador, sus notificaciones locales fallaban con `UNErrorDomain 2003` con el permiso
  concedido. Está en `docs/aprendizajes-tecnicos.md`.
