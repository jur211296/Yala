# Tanda de QA de Jürgen — 2.1

Barrido del 2026-10-12, sobre `origin/2.1` en `1add0d930` (#473). Repite el del 10-oct con lo que entró después: los
PRs #451 a #473.

- **Revisado:** las 30 cards «in qa» del tablero, los 44 tickets de `tickets/qa/` y los 23 PRs nuevos.
- **Pasan a done:** 8 cards y 6 tickets. La tabla está al final.
- **Se quedan para ti:** 22 cards en qa y 40 tickets, en 34 pruebas. Se añaden 2 cards bloqueadas que piden tus dos
  iPhone.
- **Tiempo total estimado: unas 10 h 40 min.** Lo que bloquea el lanzamiento suma **3 h 30 min**.

Los ids de card van sin el prefijo `tablero-`. «Sin card» quiere decir que el ticket no tiene tarjeta en el tablero.

## Antes de empezar

1. **Sube un build nuevo a TestFlight desde la Mini**, con `2.1` en `1add0d930` o posterior. Todo lo de esta lista
   necesita los arreglos de hoy (#454, #456, #468, #470): con un build anterior, varias pruebas fallan sin ser fallos.
2. En tu iPhone, instálalo encima del que tienes. **No borres Yala**: la prueba D2 empieza con el build anterior. Si
   quieres hacer D2, hazla primero en el iPhone de pruebas.
3. Ten a mano: el iPhone de pruebas con Yala Dev contra staging (grupo C), el segundo iPhone (grupo E) y el iPad
   (grupo F).

## Qué bloquea el lanzamiento

Si una de estas falla, 2.1 no sale: o se pierden datos, o un usuario nuevo no puede entrar, o Apple rechaza el envío.

| # | Card / ticket | Prueba | Min |
|---|---|---|---|
| 1 | `el-manifiesto-de-privacidad-no-declara-l-kgqv` | G1 · Etiquetas de App Privacy | 15 |
| 2 | `la-web-la-politica-y-la-ficha-dicen-que-i6tj` | G2 · La ficha y la App Store cuentan la nube | 5 |
| 3 | `checklist-de-envio-de-2-1-a-app-store-ve-d0ui` | G3 · Checklist de envío | 15 |
| 4 | Sin card · `welcome-private-fresh-start-skips-icloud-check` | D1 · «Primera vez › privado» mira iCloud | 20 |
| 5 | Sin card · `previous-person-cloud-session-survives-…` | D2 · Actualizar encima no cierra la sesión | 10 |
| 6 | Sin card · `groups-entry-on-a-mirrored-store-…` (2 tickets) | D3 · «Vengo por un grupo» con tus datos de iCloud | 40 |
| 7 | Sin card · `forward-migration-…` + `snapshot-upload-…` | C1 · Activar la nube | 35 |
| 8 | Sin card + `crear-otra-cuenta-con-apple-entra-en-la-ni6g` | C2 · Entrar en la nube (paso 1) | 25 |
| 9 | `validar-en-testflight-unirse-a-un-grupo-e1ah` | E1 · Unirse a un grupo con dos iPhone | 30 |
| 10 | `cambiar-la-divisa-de-una-cuenta-deja-mal-v5k7` | A1 · Cambiar la divisa de una cuenta | 10 |
| 11 | Sin card · `device-qa-apple-id-change-closes-private-session` | A2 · Apagar iCloud Drive no cierra la sesión | 5 |

**Orden recomendado:** G1-G3 primero, que no piden iPhone y Apple los mira al enviar. Luego D1, D2 y C1, que si fallan
rompen 2.1 para todo el mundo. El resto por grupos, para montar cada cosa una sola vez.

---

## G. Sin iPhone: consola y App Store Connect — 45 min

### G1 · `el-manifiesto-de-privacidad-no-declara-l-kgqv` — Etiquetas de App Privacy · 15 min · **bloquea**
1. Decide si fotos y audio van como vinculados al usuario (lo prudente) o no vinculados.
2. App Store Connect › App Privacy: copia la tabla del PR #446.
3. Xcode › Organizer › Privacy Report del archivo de 2.1, y compáralo con la tabla. Deben coincidir.

### G2 · `la-web-la-politica-y-la-ficha-dicen-que-i6tj` — La ficha cuenta la nube · 5 min · **bloquea**
Ticket: `session-redesign-web-and-store-copy`.
La web ya está: hoy `yala-app.pe/privacy` y `/en/privacy` tienen 14 secciones y «Octubre 2026», y nombran Supabase.
1. Pregunta a Lola si la ficha de los 7 idiomas ya dice que Grupos vive en la nube. Hoy `description-es.md` aún dice
   «45+ divisas» (hallazgo de #469).
2. Con G1 hecho y la ficha al día, la card pasa a done.

### G3 · `checklist-de-envio-de-2-1-a-app-store-ve-d0ui` — Checklist de envío · 15 min · **bloquea**
1. Abre `docs/RELEASE-CHECKLIST-2.1.md` y marca lo que ya está: la política (#469), el manifiesto (#446), los plist
   (#447) y el esquema de CloudKit (desplegado hoy y verificado por test).
2. Repasa las casillas que viven fuera del repo: la app de Google en «Prueba», la URL de App Store Server
   Notifications y la rama de producción de Vercel.
3. Lo que siga sin marcar es lo que te queda antes de enviar.

### G4 · `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f` — Claves del gateway · 10 min
1. Revoca la clave vieja de OpenAI.
2. Mira la caducidad de las claves gateway-staging y gateway-production.
3. Pasa a 1Password `~/Secrets/yala-gateway/{openai-staging.key, openai-prod.key, staging-dev-shared-secret}`.

---

## A. Tu iPhone, con el build nuevo — 1 h 12 min

Ordenadas por riesgo: las dos primeras bloquean.

### A1 · `cambiar-la-divisa-de-una-cuenta-deja-mal-v5k7` — Cambiar la divisa de una cuenta (2 tickets) · 10 min · **bloquea**
Tickets: `account-currency-change-leaves-scheduled-and-favorites-stale` y `changing-an-account-currency-orphans-its-whole-history`.
1. Crea la cuenta «Prueba QA» en PEN, sin movimientos, con un pago programado «Alquiler» de 3.500 para hoy y un favorito
   «Mercado» de 3.500.
2. Ajustes › Cuentas › «Prueba QA» › Moneda › USD › Guardar → sale «¿Cambiar la divisa a USD?» con el alquiler y el
   favorito convertidos (~930 USD). Cancelar → todo sigue en PEN.
3. Repite y toca Convertir → la cuenta queda en USD; el alquiler y el favorito dicen ~930 USD. Tras reabrir Yala, el
   borrador del alquiler en la Bandeja sale por ~930 USD.
4. En una cuenta con movimientos, cambia la Moneda → sale «¿Convertir N movimientos?» con el conteo real. Al aceptar,
   los importes quedan reexpresados, no el mismo número con otro símbolo.
5. Control: una cuenta con una transferencia sigue con la Moneda bloqueada.

### A2 · Sin card — Apagar iCloud Drive no cierra la sesión (`device-qa-apple-id-change-closes-private-session`) · 5 min · **bloquea**
1. En tu sesión privada con datos, abre y cierra Yala una vez.
2. Ajustes de iOS › iCloud › apaga iCloud Drive, sin cerrar sesión ni cambiar de cuenta.
3. Abre Yala → **no** debe salir «Cambiaste de cuenta de iCloud». Si sale, para y avisa.
4. Vuelve a encender iCloud Drive.

### A3 · `borrar-un-gasto-de-la-bandeja-de-entrada-yneu` — La x de la Bandeja borra de verdad · 10 min
Ticket: `inbox-dismiss-x-does-not-delete-the-draft-for-good`.
1. Planificación › nuevo pago programado «QA alquiler», mensual, con fecha de ayer y una cuenta.
2. Cierra Yala del todo y ábrela → «QA alquiler» aparece en la Bandeja.
3. Ábrelo y toca la x de arriba a la derecha. Cierra y abre Yala, y vuelve tras más de un minuto en otra app → no
   vuelve a la Bandeja; está en Archivados.
4. Planificación › «QA alquiler» → la fecha de ayer sale saltada y la próxima es el mes que viene.
5. Archivados › «Volver a pendientes» y apruébalo → la próxima fecha sigue siendo el mes que viene.

### A4 · `el-delegado-de-notificaciones-se-asigna-bdxj` + Sin card (`scheduled-payments-notif-dedup`) — Notificaciones con Yala cerrada · 20 min (10 son espera)
Tickets: `notification-delegate-assigned-after-launch` (#454) y `scheduled-payments-notif-dedup`.
El toque en frío y el resumen agendado no se pueden ver en el simulador: pasan por la pantalla de bloqueo.
1. Ajustes de iOS › Yala › Notificaciones: permitidas. En Yala, Planificación › nuevo pago «QA luz» de 50, recurrencia
   **«Una sola vez»**, fecha de hoy. Con otra recurrencia, el editor lo fecha el mes que viene.
2. Perfil › Notificaciones › «Pagos planificados» activo, con la hora a 10 minutos vista.
3. Cierra Yala del todo (deslizar hacia arriba en el selector de apps) y bloquea el iPhone. A la hora llega **una**
   notificación «Tienes 1 pago planificado para hoy».
4. Tócala con Yala cerrada → Yala se abre y, al terminar de cargar, va a **Pagos planificados**. Si se queda en el
   Panel, es el fallo.
5. Abre Yala otra vez → no llega una segunda notificación del mismo pago.
6. Mientras esperas el paso 3: Planificación › Presupuestos › uno de 10 para una categoría y un gasto de 20 en ella.
   Cierra Yala del todo y toca el aviso de presupuesto → abre **Presupuestos**.
7. Borra el pago, el presupuesto y el gasto de prueba.

### A5 · `el-flujo-de-caja-cuenta-un-pago-programa-r6pd` — Un pago en dólares en el flujo de caja · 5 min
Ticket: `cashflow-scheduled-line-ignores-payment-currency`.
1. Con la divisa preferida en PEN, crea un pago programado mensual de 100 USD.
2. Informes › Flujo de caja › «Añadir línea» desde pago programado → la fila muestra ~375 PEN, no 100.
3. Abre un mes futuro → la línea y el total de gastos del mes llevan el importe convertido, con «≈» si no hay tasa exacta.
4. Un pago en PEN se ve igual que antes.

### A6 · `decidir-el-aviso-no-pudimos-cerrar-tu-se-7m1e` — «No pudimos cerrar tu sesión» al desasociar sin red · 5 min
1. Con tu cuenta de grupos asociada, pon el modo avión y apunta un gasto en un grupo.
2. Perfil › «Dónde viven tus datos» › Grupos › «Desasociar» y confirma → la sección dice que hay cambios sin subir y no
   desasocia.
3. Ve a Perfil y espera unos segundos → **no** debe salir «No pudimos cerrar tu sesión».
4. Quita el modo avión. Si no salió, la card se descarta. Si salió, haz una captura: toca reescribir el texto.

### A7 · `qa-iphone-ajustes-como-listas-agrupadas-5sr2` — Ajustes como listas agrupadas · 7 min
Ticket: `settings-redesign-as-grouped-lists-like-ios`.
1. Perfil › Personalización → bloques sobre el fondo, línea fina entre filas y cabecera gris pequeña. Baja hasta el
   final: están los 13 ajustes.
2. Perfil › Temas › uno oscuro y vuelve → los bloques se distinguen del fondo sin borde.
3. Repite con un tema traslúcido.
4. Abre Divisa y Cambio, Vaciar datos (sin confirmar), Privacidad y datos IA y Tutoriales → todo funciona igual que antes.

### A8 · Sin card — Pasos guiados como la referencia del 15-sep (`step-flows-should-match-the-sep15-reference`) · 10 min
1. Avatar › Ayuda › Tutoriales › «Registrar con Apple Pay» → «Paso 1 de 4».
2. «Abrir Atajos» y vuelve a Yala → la guía está en «Paso 2 de 4», con el paso 1 marcado.
3. «Hecho» hasta «Paso 4 de 4» y reproduce el vídeo.
4. «Me atasqué» abre el formulario de soporte; ciérralo y «Listo» → el tutorial queda marcado.
5. Ajustes › Seguridad › «Protege Yala con Face ID» → «Hecho» avanza los 3 pasos.

---

## B. Cuenta Pro, en tu iPhone — 1 h 22 min

Ninguna bloquea: si una falla, la función de IA queda peor, pero nadie pierde datos.

### B1 · `mejorar-el-registro-por-imagen-de-punta-g5wl` + `un-estado-de-cuenta-en-pdf-solo-se-lee-e-4j2s` + `al-compartir-una-imagen-a-yala-la-lectur-nxle` — Registro por foto o archivo · 30 min
Tickets: `image-entry-end-to-end-redesign`, `pdf-statement-reads-only-the-first-page` y `share-image-reading-does-not-always-start`.
1. Panel › imagen › Cámara (acepta el permiso la primera vez) y fotografía un recibo → «Leyendo tu foto…» y luego
   «Esto leí». Guardar → el disponible baja ese importe. Si es antes del mediodía, «Guardar» sale encendido (#463).
2. Fotos › tres recibos → «Foto 1 de 3…» y «Guardar 3». Modo avión › una foto → «Sin conexión» con Reintentar.
3. Archivo › un estado de cuenta de 3 páginas o más → «Página 1 de 3»… y salen los movimientos de todas las páginas,
   sin saldos ni subtotales. Con un PDF con contraseña → la pide; con una mala → «Contraseña incorrecta»; con la buena
   → lo lee.
4. Con Yala cerrada del todo: Fotos › recibo › Compartir › Yala → «Leyendo tu foto…» y «Esto leí».
5. Con la Bandeja abierta, ve al inicio y comparte otra → **la Bandeja se cierra sola** y arranca la lectura (#468).
6. En el Panel, abre «Nuevo registro» y escribe un importe. Comparte otra foto → el formulario **no** se cierra; al
   cerrarlo tú, arranca la lectura.
7. Repite el paso 4 tres veces seguidas desde el Panel: las tres se leen.

### B2 · `yala-no-aparece-al-compartir-varias-capt-3ut5` — Compartir varias fotos a la vez · 12 min
Ticket: `sharing-several-photos-hides-yala` (#456).
1. Fotos › selecciona **3 capturas** de movimientos › Compartir → Yala aparece en la fila de apps.
2. Tócala → Yala se abre en el Panel con «Leyendo» (1 de 3, 2 de 3…) y luego una fila por movimiento.
3. Cierra la hoja con la X sin guardar → los borradores están en la Bandeja.
4. Repite con **12 capturas** → se leen 10 y debajo sale «Quedaron 2 fotos sin leer…».
5. Repite con **10 fotos grandes de la cámara** → la extensión no se cierra sola y llegan las 10.

### B3 · `mejorar-el-registro-por-voz-de-punta-a-p-u58k` + `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f` — Voz e idiomas de voz · 25 min
Tickets: `voice-entry-end-to-end`, `ai-every-call-sends-its-task-and-passes-the-bench` y `vision-reads-every-dollar-sign-as-usd`.
1. Panel › icono de onda → la hoja sube a media altura y ya escucha. Di «taxi 12 y café 8» → dos filas, y «Guardar 2»
   registra las dos.
2. Con música en otra app, abre Voz y Cancelar → la música vuelve. Con modo avión → «Sin conexión» con «Usar imagen» y
   «Volver a grabar».
3. Ajustes › Personalización › Idioma de voz → «Idioma de la app» y los 10 idiomas. Dicta «Ayer 25 soles con 50 en
   <tu comercio habitual>» → 25,50 y el comercio bien escrito.
4. Elige English y dicta «Coffee 4.50 at Starbucks» → borrador de 4,50. Vuelve a «Idioma de la app».
5. Con la divisa principal en PEN, foto de un ticket con «$ 25.00» a secas → el borrador sale sin divisa decidida, no
   en USD.
6. Con la divisa principal en MXN y una cuenta en MXN, foto de un ticket con «$250» → 250 MXN en esa cuenta. Vuelve a
   tu divisa.

### B4 · `mejorar-cards-de-registros-nuevos-en-yal-rdfd` + `mejorar-el-diseno-del-dictado-en-yala-ai-apsc` — El chat de Yala IA · 15 min
Tickets: `chat-draft-card-redesign`, `chat-dictation-looks-poor` y `ai-chat-reads-heavier-than-a-messaging-app`.
1. Abre Yala IA → saludo en una burbuja con tres preguntas; arriba, la fecha y los avisos en gris pequeño. Toca una
   pregunta: se envía como si la hubieras escrito.
2. Escribe «Gasté 45 en un taxi y 120 en el súper» → una fila por registro con píldoras. Si falta subcategoría, la
   píldora ámbar la pide y «Guardar» se enciende al elegirla.
3. Cambia la cuenta por una de otra divisa → cambia el símbolo. «Guardar» → «✓ Registrado» y el saldo de la cuenta baja.
4. Toca el micro → panel «Escuchando…» con el orbe; el halo crece con la voz. Cancelar → vuelve la caja vacía y la
   música de otra app vuelve a sonar.
5. Dicta «gasté 25 en el almuerzo con la tarjeta» y toca Listo → el texto queda en la caja, sin enviarse.

---

## C. iPhone de pruebas con Yala Dev contra staging — 3 h 31 min

Datos que no importen y una cuenta de nube de pruebas en staging. Para C3, además, la Consola del Mac con el iPhone
por cable.

### C1 · Sin card — Activar la nube: techos y «Cancelar la activación» (`forward-migration-steps-have-no-ceiling-and-no-exit` + `snapshot-upload-has-no-ceiling-and-no-way-out`) · 35 min · **bloquea**
1. Con muchos movimientos y la cuenta de staging sin migrar: Perfil › «Dónde viven tus datos» › «Migrar a la nube» ›
   consentimiento › iniciar sesión.
2. Al llegar al 55 %, pon el modo avión → aparece «Cancelar la activación» bajo «Retomar».
3. «Cancelar la activación» › «Seguir activando la nube» → no cambia nada. Otra vez › «Sí, cancelar» → vuelve a
   «Migrar a la nube», sin aviso de error.
4. Quita el modo avión y migra sin tocar nada → la barra pasa por 22, 35, 55, 75 y 80 % sin pararse y acaba en «cierra
   y vuelve a abrir Yala». Al reabrir, el modo nube está activo.

### C2 · Sin card + `crear-otra-cuenta-con-apple-entra-en-la-ni6g` — Entrar en la nube (3 tickets) · 25 min · **el paso 1 bloquea**
Tickets: `cloud-sign-in-discovers-account-kind`, `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` y
`born-cloud-signup-lands-on-existing-account-silently`. **El paso 2 necesita el PR #427, que sigue en conflicto**: sáltalo
hasta que entre.
1. Borra y reinstala Yala, y espera 10 s con red en la primera pantalla. «Empezar» › «Es mi primera vez» → salen «Tu
   cuenta en la nube» y «Tu cuenta en tu iCloud privado». Si falta la de la nube, para: es grave.
2. *(Con #427.)* Con un Apple ID que ya tiene cuenta en la nube: «Crear otra cuenta» › «Tu cuenta en la nube» ›
   consentimiento › «Registrarse con Apple» → «Ya tenías una cuenta, has entrado en ella» › «Empezar» → la app con sus
   datos, sin onboarding.
3. Reinstala › «Ya tengo cuenta» › Google con una cuenta que solo usaste para grupos → aterriza en la puerta de Grupos,
   no en el Panel. Fuerza el cierre y reabre: los grupos siguen.
4. Reinstala › «Ya tengo cuenta» con una cuenta sin Yala → «No encontramos una cuenta». Su botón abre el consentimiento
   con ese proveedor y el alta crea la cuenta.

### C3 · Sin card — «Volver a iCloud» para una cuenta nacida en la nube (`reverse-cutover-cerrado-para-cuentas-born-cloud`) · 60 min
1. Crea una cuenta nueva por «Primera vez › nube» con 15-20 movimientos en 2-3 cuentas, un presupuesto y un pago
   recurrente → el panel DEBUG dice «eligible ✅ · born-cloud».
2. Borra 2-3 movimientos y una cuenta, y apúntalos.
3. Perfil › «Dónde viven tus datos» › «Volver a iCloud» → pasa las dos confirmaciones; reabre cuando lo pida y apunta
   cuánto tardó. La barra debe decir «Subiendo».
4. En CloudKit Console, la base privada tiene los registros.
5. La app queda en modo privado con todo visible, y lo borrado en el paso 2 sigue borrado.

### C4 · `tras-volver-a-icloud-un-movimiento-cread-amad` — Tras volver a iCloud, un movimiento pierde su cuenta · 45 min (casi todo espera; puede ir tras C1)
Ticket: `cloud-tx-epoch-orphan-relations`.
1. Con la Consola filtrando «danglingRef» y la cuenta ya en la nube, crea «QA rápida 1» y «QA rápida 2» con cuenta y
   subcategoría.
2. Antes de 5 min, «Volver a iCloud» y reinicia cuando lo pida → en Registros, los dos conservan cuenta y subcategoría,
   también tras reabrir.
3. Anota si la Consola mostró «danglingRef».
4. Migra otra vez, crea «QA lenta», espera 30 min con Yala abierta, vuelve a iCloud y repite la comprobación. Si se
   pierde algo, el ticket sube a very-high.

### C5 · `decidir-tras-cancelar-la-entrada-con-la-069g` — «Borrar todo y continuar» con cambios de grupos · 20 min
Ticket: `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes`.
1. Con datos privados, apunta un gasto en un grupo en modo avión y llega a la bienvenida conservándolo.
2. «Ya tengo una cuenta» › entra con la nube › «Cancelar la activación» y confirma → vuelves a la elección.
3. «Soy nuevo» › «Privacidad total» › «Cancelar» → vuelves a la elección.
4. Repite y toca «Borrar todo y continuar» → se abre la puerta privada, no «inténtalo en un rato». Atrás → vuelves a la
   elección con tus datos.
5. Repite y acepta perder los cambios con su «¿seguro?» → se borra todo y empieza el onboarding privado.

### C6 · Sin card — El consentimiento de Grupos queda registrado (`groups-consent-door-spec`) · 15 min
1. Instalación fresca con una cuenta Apple o Google de pruebas: «Vengo por un grupo» › «Crear mi primer grupo» →
   explicación › entrar › «Grupos en la nube» › «¿Cómo te llamas?».
2. «Aceptar y continuar», pon tu nombre y crea un grupo.
3. Avisa a Frank: comprueba en staging que hay **una** fila de consentimiento de esa cuenta.
4. Cierra sesión y vuelve a entrar por «Vengo por un grupo» con la misma cuenta → no vuelve a salir «Grupos en la
   nube», y sigue habiendo una sola fila.

### C7 · `tras-vaciar-los-datos-desde-otro-disposi-pb6r` — El widget en una sesión solo de grupos · 6 min
Ticket: `after-session-redesign-review-widgets-siri-applepay-and-web-copy`.
1. Entra en Yala por «Vengo por un grupo».
2. Añade el widget Balance → dice «Aún no tienes finanzas personales · Activar Yala completo».
3. Tócalo → se abre Yala en «Activar Yala completo».
4. Termina la activación → el widget pasa a mostrar el saldo.

### C8 · Sin card — Entrada y login como la referencia del 15-sep (`onboarding-login-should-match-the-sep15-reference`) · 5 min
1. Reinstala y toca «Empezar» → píldora «‹ Volver», titular serif y tres opciones en una tarjeta, sin logo.
2. «Ya tengo una cuenta» → «¡Hola de nuevo!», Apple y Google en blanco, una «o», «Restaurar desde iCloud» con borde y
   «¿Es tu primera vez en Yala? Empieza aquí».
3. «Empieza aquí» → abre «Es mi primera vez».
4. Con el texto al máximo, repite el paso 1 → el titular no queda bajo la píldora y la pantalla hace scroll.

---

## D. TestFlight — 2 h 35 min

Usa un iPhone de pruebas con tu Apple ID: estas pruebas leen tus datos reales de iCloud, y solo TestFlight ve ese
contenedor. Ninguna borra iCloud salvo que lo elijas.

### D1 · Sin card — «Primera vez › privado» mira iCloud antes de empezar (`welcome-private-fresh-start-skips-icloud-check`) · 20 min · **bloquea**
1. Apunta cuántos movimientos y cuentas tienes, y el mes del más antiguo. Desinstala e instala Yala.
2. «Es mi primera vez» › «Tu cuenta en tu iCloud privado» → «Revisando qué hay en tu iCloud…» y luego un aviso con
   cifras que casan con lo apuntado.
3. Si en cambio sale siempre «No pudimos conectarnos a iCloud», para: es el fallo que bloquearía a todo usuario nuevo.
4. Toca volver → regresas a la elección. Entra otra vez por privado → mismas cifras; «Traer mis datos».

### D2 · Sin card — Actualizar encima no cierra la sesión (`previous-person-cloud-session-survives-fresh-start-and-reinstall`) · 10 min · **bloquea**
1. Con el build anterior, entra con una cuenta de nube de prueba y crea un grupo → Perfil › «Dónde viven tus datos»
   muestra su correo.
2. Instala el build nuevo **encima**, sin borrar → la sesión sigue abierta y Grupos entra sin pedir nada. Este paso
   decide si se puede publicar.
3. Borra Yala y reinstala → Welcome de instalación nueva; «Ya tengo una cuenta» pide elegir y no entra solo.
4. Entra con la cuenta de prueba → recupera sus grupos.

### D3 · Sin card — «Vengo por un grupo» en un teléfono con tus datos de iCloud (2 tickets) · 40 min · **bloquea**
Tickets: `groups-entry-on-a-mirrored-store-still-blocks-the-owner` y `groups-only-second-launch-mounts-icloud-mirror`.
1. Borra Yala, reinstala, «Primera vez» › iCloud privado › «Restaurar mis datos» y deja que baje. Mata la app.
2. Vuelve al Welcome › «Vengo por un grupo» › «Crear mi primer grupo» → nada de «Aquí ya hay datos guardados»; sale
   «Estamos subiendo tus últimos cambios a iCloud…» y te pide reabrir.
3. Reabre → puerta de Grupos y sign-in sin elegir de nuevo; crea el grupo. Mata y abre tres veces → solo Grupos; nada
   de tus cuentas ni movimientos de iCloud.
4. Cierra la sesión de Grupos y reabre → nada del histórico.
5. Reinstala › «Ya tengo cuenta» › «Restaurar desde iCloud» → vuelve **todo** el histórico. Vacío es fallo grave.

### D4 · Sin card — Cerrar la sesión privada no pierde lo que no subió (`session-exits-one-verb-per-session`) · 35 min
1. En la sesión privada, crea un gasto, espera 10 s y Perfil › «Cerrar sesión» → cierra sin aviso.
2. «Ya tengo cuenta» › «Restaurar desde iCloud» → todos tus datos, incluido ese gasto.
3. Modo avión, crea un gasto y cierra sesión → «Guardando tus cambios…» y, a los 45 s, un aviso con «1».
4. «Esperar» y quita el modo avión → cierra sola.
5. Repite el paso 3 y fuerza el cierre de Yala durante la espera → al reabrir, la sesión y los datos siguen ahí.

### D5 · Sin card — «Activar Yala completo» pregunta dónde guardar tus finanzas (`full-mode-activation-must-ask-where-personal-data-lives`) · 30 min
1. Reinstala › «Vengo por un grupo» › crea un grupo y apunta un gasto tuyo y otro del otro miembro.
2. Perfil › «Activar Yala completo» → «¿Dónde guardamos tus finanzas?» con dos tarjetas.
3. «Tu cuenta en tu iCloud privado» → aviso con cifras y tres botones (restaurar, borrar, cancelar).
4. «Restaurar mis datos» › reabre › «Restaurar» › «Continuar» → tus datos de antes, con tu nombre y tu divisa.
5. Registros → cada gasto de grupo aparece una sola vez.

### D6 · Sin card — «Empezar desde cero» en Restaurar (`restore-start-fresh-keeps-the-imported-corpus`) · 20 min
1. Apunta tus cifras de iCloud; desinstala e instala.
2. «Ya tengo una cuenta» › «Restaurar desde iCloud» › «Empezar desde cero» › confirmar → sale una puerta con cifras que
   casan y tres salidas, no el onboarding.
3. «Traer mis datos» › Restaurar › «Continuar» → los datos vuelven completos.
4. Cierra y reabre un par de veces → siguen ahí.

---

## E. Dos iPhone — 1 h 5 min

E2 y E3 piden la misma cuenta en los dos. E1 pide dos cuentas distintas y los dos con el build de TestFlight: un build
de Xcode da 401 contra producción.

### E1 · `validar-en-testflight-unirse-a-un-grupo-e1ah` — Unirse a un grupo por enlace · 30 min · **bloquea**
La card estaba en `blocked` a la espera de tus dos iPhone. Nadie ha unido a dos personas por el canal de la nube en
producción. Ticket: `tickets/blocked/groups-join-intent-reconciler.md`.
1. iPhone A, tu cuenta: crea el grupo «QA unión» y comparte su enlace de invitación con el iPhone B.
2. iPhone B, instalación nueva con otra cuenta de Apple o Google: abre el enlace › «Unirme» › entra. Debe decir
   «Conectando con tu grupo…» y luego «Esperando aprobación», nunca «¡Todo listo!» de golpe.
3. iPhone A: llega «X quiere unirse» y la solicitud está en el detalle del grupo. Aprueba.
4. iPhone B: el grupo se abre solo. Apunta un gasto de 30 → en el iPhone A aparece en menos de un minuto, con el saldo
   correcto. B no recibe ningún aviso de «se unió».
5. Repite con un grupo nuevo y en el paso 2, **mata la app de B** antes de que aparezca el grupo. Relanza → la unión se
   completa sola y a A le llega la solicitud.

### E2 · `en-el-segundo-dispositivo-de-una-cuenta-gk5w` — Reintentar «Volver a iCloud» en el segundo iPhone · 20 min
Ticket: `reverse-exit-on-a-reverted-account-rejects-the-retry`. El arreglo de servidor (g17_01) está en staging y
producción desde el 9-oct.
1. Dos iPhone con la misma cuenta en la nube, los dos en modo nube.
2. En el primero, Perfil › «Dónde viven tus datos» › «Volver a iCloud» hasta terminar.
3. En el segundo, «Volver a iCloud» → sale la espera; cancélala.
4. Reintenta en el segundo → avanza. No debe salir «tu cuenta no lo permitía».

### E3 · `las-preferencias-se-volvian-a-guardar-so-d44s` — Un ajuste viaja al otro iPhone · 15 min
La card estaba en `blocked` a la espera de dos aparatos con el mismo iCloud. Ticket:
`tickets/blocked/apppreferences-rewritten-on-launch.md`.
1. iPhone A: Perfil › Personalización › activa «Solo gastos». A los pocos minutos, el iPhone B lo tiene activado.
2. iPhone A: concede el permiso de notificaciones desde el primer aviso → en el B, las alertas de presupuesto salen
   activadas.
3. Cierra Yala en el A. En el B, cambia la divisa principal. Abre el A → tiene la divisa nueva; abrirlo no la pisa.

---

## F. iPad — 10 min

### F1 · `receiptdropuitests-test-lockedpdf-falla-pbwh` — Un PDF con contraseña en el iPad · 10 min
Ticket nuevo: `ipad-locked-pdf-password-may-crash-on-open`. En el simulador del iPad, Yala se cerró una de cinco veces
al pulsar «Abrir». Hay que saber si pasa en un iPad real.
1. En el Mac: Vista Previa › Exportar › «Cifrar» un PDF de 2-3 páginas, y pásalo al iPad por AirDrop.
2. iPad, Yala a pantalla completa: Panel › imagen › Archivo › el PDF. Escribe la contraseña y pulsa **Abrir** con el
   teclado aún arriba → lee las páginas. Si Yala se cierra, es el fallo.
3. Repítelo cinco veces; una de ellas, con el «Intro» del teclado.
4. Con Archivos y Yala en Split View, **arrastra** el PDF sobre Yala → pide la contraseña y lo lee.
5. Si se cerró: Ajustes › Privacidad › Análisis › Datos de análisis › el `Yala-…` más reciente, para Frank.

No bloquea, salvo que Yala se cierre: entonces es un bug de producto que lee mal los estados de cuenta protegidos.

---

## Fuera de la tanda: no te toca

| Card / ticket | Por qué sigue abierto | Quién |
|---|---|---|
| PR #427 (`crear-otra-cuenta-con-apple-entra-en-la-ni6g`) | En cola de auto-merge pero en **conflicto** (DIRTY) desde el 11-oct: no entra solo. Mientras no entre, el paso 2 de C2 no se puede probar. | La sesión de #427, o Frank si se lo pides |
| `receiptdropuitests-test-lockedpdf-falla-pbwh` | Además de F1, el test sigue intermitente en el simulador del iPad. | Frank |
| PR #474 (capturas es-MX) | Abierto y bloqueado por el CI. Solo trae una semilla de desarrollo y cuatro tickets de backlog: no toca la app publicada. | Lola / su sesión |

---

## Lo que pasó a done

| Card | Ticket | Motivo |
|---|---|---|
| `el-esquema-de-icloud-del-repo-no-tiene-c-o2li` | El esquema de iCloud del repo no tiene campos que la app escribe (`personal-cloudkit-schema-snapshot-misses-optional-fields`, estaba en blocked) | Desplegaste el esquema el 12-oct. Con los cuatro `.ckdb` exportados después, `PersonalCloudKitSchemaParityTests` sale en verde: cada campo que la app escribe existe en Production. |
| `la-qa-nocturna-se-corta-por-tiempo-cada-7zso` | La QA nocturna se corta por tiempo cada noche (`nightly-ui-suite-hits-its-110-minute-cap-every-night`) | Es CI. Las nocturnas del 10, 11 y 12-oct cumplen los tres criterios del ticket. Cada tanda cierra todas sus suites (hasta 30/30/30). El paso de UI más largo dura 74 min (tope 110), el job de UI 91 min (tope 135) y el de tests 38 min (tope 45). |
| `la-politica-y-los-terminos-no-cuentan-el-bis6` | La política y los términos no cuentan el Modo Nube (`privacy-policy-and-terms-miss-cloud-mode-identifiers-and-account-deletion`) | La web está desplegada y medida hoy con curl: 14 secciones y «Octubre 2026» en /privacy y /en/privacy, y nombra Supabase. Lola aprobó el texto (#469) y `ExportFreePeriodsUITests` fija la exportación gratis. |
| `en-ipad-al-cambiar-de-grupo-el-detalle-s-46n1` | En iPad, al cambiar de grupo el detalle se queda con el primero (`ipad-group-detail-keeps-the-first-group-after-switching`) | `AdaptiveNavigationUITests` sale rojo sin el arreglo y verde con él en el iPad Pro 13 simulado, para grupos y presupuestos, con capturas (#473). El arreglo es la identidad de la vista, no un cálculo. |
| `con-datos-en-el-telefono-y-sin-icloud-es-gwfi` | «Es mi primera vez › privado» con el teléfono ilegible (`private-gate-device-notice-has-no-forward-exit`) | Implementada tu decisión «solo lo alcanzable» (#470). La cubren `PrivateGateDeviceUnreadableUITests` y `PrivateGateDeviceUnreadableTests` con un mutante. En un iPhone el error de lectura no se provoca, y la pantalla nueva no borra nada. |
| `decidir-tras-reintentar-una-migracion-fa-l36m` | Tras «Reintentar» una migración fallida, el borrado de iCloud pendiente (`retry-after-a-failed-migration-resumes-the-pending-icloud-wipe-blindly`) | Implementada tu opción A (#470): donde antes borraba, ahora pregunta. `MigrationRunnerTests` §9d recorre el caso entero con un mutante rojo. Montarlo a mano pide que falle a propósito una ida real a la nube. |
| `una-foto-compartida-espera-sin-avisar-de-msje` | — (el ticket ya estaba en done) | Implementada tu opción B (#468). `SharedImageEntryUITests` sale rojo sin el cierre en los casos de la Bandeja, el «?» y «elige una foto», y `SharedPhotoPanelSheetLogicTests` fija la lista entera. Lo vuelves a ver en B1, pasos 5 y 6. |
| `voz-imagen-o-nuevo-registro-desde-un-wid-0ekl` | — (el ticket ya estaba en done) | Implementada tu opción A (#468). `WidgetEntryToPanelUITests` sale rojo sin el arreglo y verde con él para voz, imagen y nuevo registro. El widget y Siri entran por el mismo enlace que el test. |

### PRs #451 a #473 que no necesitan tu iPhone

| PR | Por qué no |
|---|---|
| #451, #452, #458, #460, #461, #465, #466 | Conversiones a la divisa principal en Tendencias, widgets, IA, grupos y Estadísticas. Con una sola divisa no cambia nada visible y ningún seed crea filas sin recalcular; cada uno trae su test con control rojo. |
| #453, #459 | Lo que se abre desde fuera espera a que cierres la hoja de otra pestaña. Rojo→verde en `ExternalEntryForeignSheetUITests`, que entra por el mismo enlace. |
| #455 | El aviso «¿era de prueba?» espera a la pantalla de éxito. `FirstExpensePracticeAlertUITests` con el seed `sin-registros`, rojo→verde. |
| #457 | Las entradas del widget sobreviven al segundo plano. `WidgetEntryBackgroundUITests` y un mutante. |
| #462, #464, #467 | Solo tests y goldens del CI. |
| #463 | «Guardar» por la mañana con foto o voz. Lógica pura con reloj y zona inyectados, 9/9 en tres zonas. Lo ves de paso en B1. |
| #469 | Textos legales: la parte de la app la cubren tests y la web está medida (card `bis6`). |
| #471, #472 | Una semilla de desarrollo, y siete textos que decidiste hoy con sus capturas. |
| #454, #456, #468, #470, #473 | Sí la necesitan o la tenían: van en A4, B2, B1, y en la tabla de arriba. |
