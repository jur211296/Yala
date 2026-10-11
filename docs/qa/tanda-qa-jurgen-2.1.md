# Tanda de QA de Jürgen — 2.1

Barrido del 2026-10-10. Se revisaron las 51 cards «in qa» del tablero y los 76 tickets de `tickets/qa/`.

- **Pasan a done:** 40 tickets y 29 cards. La tabla está al final.
- **Vuelve a backlog:** 1 ticket con su card (la política del canario del adopt, explicada abajo).
- **Se quedan para ti:** 28 pruebas, que agrupan 34 tickets y 19 cards.
- **Tiempo total estimado: unas 9 h** (8 h 25 min con iPhone y 45 min de consola).

Qué se quedó: casi todo toca la nube, migraciones o borrado de datos, y solo tiene tests unitarios. El encargo
no deja cerrarlo sin una prueba real. El resto son rediseños que pediste y aún no has visto en tu iPhone.

Los ids de card van sin el prefijo `tablero-`. «Sin card» quiere decir que el ticket no tiene tarjeta en el tablero.

## Orden recomendado

1. **G. Sin iPhone**: el esquema de CloudKit puede bloquear el envío.
2. **C1 y D2**: migración a la nube y «Primera vez › privado». Si fallan, rompen la release para todos.
3. El resto por grupos, para montar cada cosa una sola vez.

---

## A. Tu iPhone, con el build de 2.1 que ya usas — 52 min

### A1 · `borrar-un-gasto-de-la-bandeja-de-entrada-yneu` — Borrar un gasto de la Bandeja con la x no lo borra · 10 min
1. Planificación › nuevo pago programado «QA alquiler», mensual, con fecha de ayer y una cuenta.
2. Cierra Yala del todo y ábrela → «QA alquiler» aparece en la Bandeja.
3. Ábrelo y toca la x de arriba a la derecha. Cierra y abre Yala, y vuelve tras más de un minuto en otra app → no vuelve a la Bandeja; está en Archivados.
4. Planificación › «QA alquiler» → la fecha de ayer sale saltada y la próxima es el mes que viene.
5. Archivados › «Volver a pendientes» y apruébalo → la próxima fecha sigue siendo el mes que viene, no dentro de dos meses.

### A2 · `cambiar-la-divisa-de-una-cuenta-deja-mal-v5k7` — Cambiar la divisa de una cuenta (2 tickets) · 10 min
Tickets: `account-currency-change-leaves-scheduled-and-favorites-stale` y `changing-an-account-currency-orphans-its-whole-history`.
1. Crea la cuenta «Prueba QA» en PEN, sin movimientos, con un pago programado «Alquiler» de 3.500 para hoy y un favorito «Mercado» de 3.500.
2. Ajustes › Cuentas › «Prueba QA» › Moneda › USD › Guardar → sale «¿Cambiar la divisa a USD?» con el alquiler y el favorito convertidos (~930 USD). Cancelar → todo sigue en PEN.
3. Repite y toca Convertir → la cuenta queda en USD; el alquiler y el favorito dicen ~930 USD. Tras reabrir Yala, el borrador del alquiler en la Bandeja sale por ~930 USD.
4. En una cuenta con movimientos corrientes, cambia la Moneda → sale «¿Convertir N movimientos?» con el conteo real; al aceptar, los importes quedan reexpresados, no el mismo número con otro símbolo.
5. Control: una cuenta con una transferencia sigue con la Moneda bloqueada.

### A3 · `el-flujo-de-caja-cuenta-un-pago-programa-r6pd` — El flujo de caja cuenta un pago en dólares como soles · 5 min
1. Con la divisa preferida en PEN, crea un pago programado mensual de 100 USD.
2. Informes › Flujo de caja › «Añadir línea» desde pago programado → la fila muestra ~375 PEN, no 100.
3. Abre un mes futuro → la línea y el total de gastos del mes llevan el importe convertido, con «≈» si no hay tasa exacta.
4. Un pago en PEN se ve igual que antes.

### A4 · `decidir-el-aviso-no-pudimos-cerrar-tu-se-7m1e` — El aviso «No pudimos cerrar tu sesión» al desasociar sin red · 5 min
1. Con tu cuenta de grupos asociada, pon el modo avión y apunta un gasto en un grupo.
2. Perfil › «Dónde viven tus datos» › Grupos › «Desasociar» y confirma → la sección dice que hay cambios sin subir y no desasocia.
3. Ve a Perfil y espera unos segundos → **no** debe salir «No pudimos cerrar tu sesión».
4. Quita el modo avión. Si no salió, la card se descarta. Si salió, haz una captura: toca reescribir el texto.

### A5 · Sin card — Cambiar de Apple ID ofrece cerrar la sesión privada (`device-qa-apple-id-change-closes-private-session`) · 5 min
1. En tu sesión privada con datos, abre y cierra Yala una vez.
2. Ajustes de iOS › iCloud › apaga iCloud Drive, sin cerrar sesión ni cambiar de cuenta.
3. Abre Yala → **no** debe salir «Cambiaste de cuenta de iCloud». Si sale, para y avisa.
4. Vuelve a encender iCloud Drive.

### A6 · `qa-iphone-ajustes-como-listas-agrupadas-5sr2` — Ajustes como listas agrupadas · 7 min
1. Perfil › Personalización → bloques sobre el fondo, línea fina entre filas y cabecera gris pequeña. Baja hasta el final: están los 13 ajustes.
2. Perfil › Temas › uno oscuro y vuelve → los bloques se distinguen del fondo sin borde.
3. Repite con un tema traslúcido.
4. Abre Divisa y Cambio, Vaciar datos (sin confirmar), Privacidad y datos IA y Tutoriales → todo funciona igual que antes.

### A7 · Sin card — Pasos guiados como la referencia del 15-sep (`step-flows-should-match-the-sep15-reference`) · 10 min
1. Avatar › Ayuda › Tutoriales › «Registrar con Apple Pay» → «Paso 1 de 4».
2. «Abrir Atajos» y vuelve a Yala → la guía está en «Paso 2 de 4», con el paso 1 marcado.
3. «Hecho» hasta «Paso 4 de 4» y reproduce el vídeo.
4. «Me atasqué» abre el formulario de soporte; ciérralo y «Listo» → el tutorial queda marcado.
5. Ajustes › Seguridad › «Protege Yala con Face ID» → «Hecho» avanza los 3 pasos.

---

## B. Cuenta Pro, en tu iPhone — 65 min

### B1 · `mejorar-cards-de-registros-nuevos-en-yal-rdfd` + `mejorar-el-diseno-del-dictado-en-yala-ai-apsc` — El chat de Yala IA · 15 min
Tickets: `chat-draft-card-redesign`, `chat-dictation-looks-poor` y `ai-chat-reads-heavier-than-a-messaging-app`.
1. Abre Yala IA → saludo en una burbuja con tres preguntas; arriba, la fecha y los avisos en gris pequeño. Toca una pregunta: se envía como si la hubieras escrito.
2. Escribe «Gasté 45 en un taxi y 120 en el súper» → una fila por registro con píldoras. Si falta subcategoría, la píldora ámbar la pide y «Guardar» se enciende al elegirla.
3. Cambia la cuenta por una de otra divisa → cambia el símbolo. «Guardar» → «✓ Registrado» y el saldo de la cuenta baja.
4. Toca el micro → panel «Escuchando…» con el orbe; el halo crece con la voz. Cancelar → vuelve la caja vacía y la música de otra app vuelve a sonar.
5. Dicta «gasté 25 en el almuerzo con la tarjeta» y toca Listo → el texto queda en la caja, sin enviarse.

### B2 · `mejorar-el-registro-por-voz-de-punta-a-p-u58k` + `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f` — Registro por voz e idiomas de voz · 25 min
Tickets: `voice-entry-end-to-end`, `ai-every-call-sends-its-task-and-passes-the-bench` y `vision-reads-every-dollar-sign-as-usd`.
1. Panel › icono de onda → la hoja sube a media altura y ya escucha. Di «taxi 12 y café 8» → dos filas, y «Guardar 2» registra las dos.
2. Con música en otra app, abre Voz y Cancelar → la música vuelve. Con modo avión → «Sin conexión» con «Usar imagen» y «Volver a grabar».
3. Ajustes › Personalización › Idioma de voz → «Idioma de la app» y los 10 idiomas. Dicta «Ayer 25 soles con 50 en <tu comercio habitual>» → 25,50 y el comercio bien escrito.
4. Elige English y dicta «Coffee 4.50 at Starbucks» → borrador de 4,50. Vuelve a «Idioma de la app».
5. Con la divisa principal en PEN, foto de un ticket con «$ 25.00» a secas → el borrador sale sin divisa decidida, no en USD.
6. Con la divisa principal en MXN y una cuenta en MXN, foto de un ticket con «$250» → 250 MXN en esa cuenta. Vuelve a tu divisa.

### B3 · `mejorar-el-registro-por-imagen-de-punta-g5wl` + `un-estado-de-cuenta-en-pdf-solo-se-lee-e-4j2s` + `al-compartir-una-imagen-a-yala-la-lectur-nxle` — Registro por imagen · 25 min
Tickets: `image-entry-end-to-end-redesign`, `pdf-statement-reads-only-the-first-page` y `share-image-reading-does-not-always-start`.
1. Panel › imagen › Cámara (acepta el permiso la primera vez) y fotografía un recibo → «Leyendo tu foto…» y luego «Esto leí». Guardar → el disponible baja ese importe.
2. Fotos › tres recibos → «Foto 1 de 3…» y «Guardar 3». Modo avión › una foto → «Sin conexión» con Reintentar.
3. Archivo › un estado de cuenta de 3 páginas o más → «Página 1 de 3»… y salen los movimientos de todas las páginas, sin saldos ni subtotales. Con un PDF con contraseña → la pide; con una mala → «Contraseña incorrecta»; con la buena → lo lee.
4. Con Yala cerrada del todo: Fotos › recibo › Compartir › Yala → «Leyendo tu foto…» y «Esto leí».
5. Con la Bandeja abierta, ve al inicio y comparte otra → al cerrar la Bandeja con la X, la lectura arranca sola. Repite tres veces seguidas desde el Panel: las tres se leen.

---

## C. iPhone de pruebas con Yala Dev contra staging — 3 h 31 min

Datos que no importen y una cuenta de nube de pruebas en staging. Para C3, además, la Consola del Mac con el iPhone por cable.

### C1 · Sin card — Activar la nube: techos y «Cancelar la activación» (`forward-migration-steps-have-no-ceiling-and-no-exit` + `snapshot-upload-has-no-ceiling-and-no-way-out`) · 35 min · very-high
1. Con muchos movimientos y la cuenta de staging sin migrar: Perfil › «Dónde viven tus datos» › «Migrar a la nube» › consentimiento › iniciar sesión.
2. Al llegar al 55 %, pon el modo avión → aparece «Cancelar la activación» bajo «Retomar».
3. «Cancelar la activación» › «Seguir activando la nube» → no cambia nada. Otra vez › «Sí, cancelar» → vuelve a «Migrar a la nube», sin aviso de error.
4. Quita el modo avión y migra sin tocar nada → la barra pasa por 22, 35, 55, 75 y 80 % sin pararse y acaba en «cierra y vuelve a abrir Yala». Al reabrir, el modo nube está activo.

### C2 · Sin card — «Volver a iCloud» para una cuenta nacida en la nube (`reverse-cutover-cerrado-para-cuentas-born-cloud`) · 60 min
1. Crea una cuenta nueva por «Primera vez › nube» con 15-20 movimientos en 2-3 cuentas, un presupuesto y un pago recurrente → el panel DEBUG dice «eligible ✅ · born-cloud».
2. Borra 2-3 movimientos y una cuenta, y apúntalos.
3. Perfil › «Dónde viven tus datos» › «Volver a iCloud» → pasa las dos confirmaciones; reabre cuando lo pida y apunta cuánto tardó. La barra debe decir «Subiendo».
4. En CloudKit Console, la base privada tiene los registros.
5. La app queda en modo privado con todo visible, y lo borrado en el paso 2 sigue borrado.

### C3 · `tras-volver-a-icloud-un-movimiento-cread-amad` — Tras volver a iCloud, un movimiento pierde su cuenta y subcategoría · 45 min (casi todo espera; puede ir tras C1)
1. Con la Consola filtrando «danglingRef» y la cuenta ya en la nube, crea «QA rápida 1» y «QA rápida 2» con cuenta y subcategoría.
2. Antes de 5 min, «Volver a iCloud» y reinicia cuando lo pida → en Registros, los dos conservan cuenta y subcategoría, también tras reabrir.
3. Anota si la Consola mostró «danglingRef».
4. Migra otra vez, crea «QA lenta», espera 30 min con Yala abierta, vuelve a iCloud y repite la comprobación. Si se pierde algo, el ticket sube a very-high.

### C4 · Sin card + `crear-otra-cuenta-con-apple-entra-en-la-ni6g` — Entrar en la nube (3 tickets) · 25 min
Tickets: `cloud-sign-in-discovers-account-kind`, `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` y `born-cloud-signup-lands-on-existing-account-silently`. **Necesita que entre el PR #427**, hoy en conflicto (ver «Fuera de la tanda»).
1. Borra y reinstala Yala, y espera 10 s con red en la primera pantalla. «Empezar» › «Es mi primera vez» → salen «Tu cuenta en la nube» y «Tu cuenta en tu iCloud privado». Si falta la de la nube, para: es grave.
2. Con un Apple ID que ya tiene cuenta en la nube: «Crear otra cuenta» › «Tu cuenta en la nube» › consentimiento › «Registrarse con Apple» → «Ya tenías una cuenta, has entrado en ella» › «Empezar» → la app con sus datos, sin onboarding.
3. Reinstala › «Ya tengo cuenta» › Google con una cuenta que solo usaste para grupos → aterriza en la puerta de Grupos, no en el Panel. Fuerza el cierre y reabre: los grupos siguen.
4. Reinstala › «Ya tengo cuenta» con una cuenta sin Yala → «No encontramos una cuenta». Su botón abre el consentimiento con ese proveedor y el alta crea la cuenta.

### C5 · `decidir-tras-cancelar-la-entrada-con-la-069g` — «Borrar todo y continuar» tras salir de la nube con cambios de grupos · 20 min
1. Con datos privados, apunta un gasto en un grupo en modo avión y llega a la bienvenida conservándolo.
2. «Ya tengo una cuenta» › entra con la nube › «Cancelar la activación» y confirma → vuelves a la elección.
3. «Soy nuevo» › «Privacidad total» › «Cancelar» → vuelves a la elección.
4. Repite y toca «Borrar todo y continuar» → se abre la puerta privada, no «inténtalo en un rato». Atrás → vuelves a la elección con tus datos.
5. Repite y acepta perder los cambios con su «¿seguro?» → se borra todo y empieza el onboarding privado.

### C6 · Sin card — El consentimiento de Grupos queda registrado (`groups-consent-door-spec`) · 15 min
1. Instalación fresca con una cuenta Apple o Google de pruebas: «Vengo por un grupo» › «Crear mi primer grupo» → explicación › entrar › «Grupos en la nube» › «¿Cómo te llamas?».
2. «Aceptar y continuar», pon tu nombre y crea un grupo.
3. Avisa a Frank: comprueba en staging que hay **una** fila de consentimiento de esa cuenta.
4. Cierra sesión y vuelve a entrar por «Vengo por un grupo» con la misma cuenta → no vuelve a salir «Grupos en la nube», y sigue habiendo una sola fila.

### C7 · `tras-vaciar-los-datos-desde-otro-disposi-pb6r` — Widget en una sesión solo de grupos · 6 min
La otra mitad de la card, el vaciado remoto, ya la cubre un test de integración: no hace falta el teléfono prestado.
1. Entra en Yala por «Vengo por un grupo».
2. Añade el widget Balance → dice «Aún no tienes finanzas personales · Activar Yala completo».
3. Tócalo → se abre Yala en «Activar Yala completo».
4. Termina la activación → el widget pasa a mostrar el saldo.

### C8 · Sin card — Entrada y login como la referencia del 15-sep (`onboarding-login-should-match-the-sep15-reference`) · 5 min
1. Reinstala y toca «Empezar» → píldora «‹ Volver», titular serif y tres opciones en una tarjeta, sin logo.
2. «Ya tengo una cuenta» → «¡Hola de nuevo!», Apple y Google en blanco, una «o», «Restaurar desde iCloud» con borde y «¿Es tu primera vez en Yala? Empieza aquí».
3. «Empieza aquí» → abre «Es mi primera vez».
4. Con el texto al máximo, repite el paso 1 → el titular no queda bajo la píldora y la pantalla hace scroll.

---

## D. TestFlight — 2 h 35 min

Usa un iPhone de pruebas con tu Apple ID: estas pruebas leen tus datos reales de iCloud, y solo TestFlight ve ese contenedor. Ninguna borra iCloud salvo que lo elijas.

### D1 · Sin card — Actualizar encima no cierra la sesión (`previous-person-cloud-session-survives-fresh-start-and-reinstall`) · 10 min
1. Con el build anterior, entra con una cuenta de nube de prueba y crea un grupo → Perfil › «Dónde viven tus datos» muestra su correo.
2. Instala el build nuevo **encima**, sin borrar → la sesión sigue abierta y Grupos entra sin pedir nada. Este es el paso que decide si se puede publicar.
3. Borra Yala y reinstala → Welcome de instalación nueva; «Ya tengo una cuenta» pide elegir y no entra solo.
4. Entra con la cuenta de prueba → recupera sus grupos.

### D2 · Sin card — «Primera vez › privado» mira iCloud antes de empezar (`welcome-private-fresh-start-skips-icloud-check`) · 20 min · imprescindible
1. Apunta cuántos movimientos y cuentas tienes, y el mes del más antiguo. Desinstala e instala Yala.
2. «Es mi primera vez» › «Tu cuenta en tu iCloud privado» → «Revisando qué hay en tu iCloud…» y luego un aviso con cifras que casan con lo apuntado.
3. Si en cambio sale siempre «No pudimos conectarnos a iCloud», para: es el fallo que bloquearía a todo usuario nuevo.
4. Toca volver → regresas a la elección. Entra otra vez por privado → mismas cifras; «Traer mis datos».

### D3 · Sin card — «Empezar desde cero» en Restaurar (`restore-start-fresh-keeps-the-imported-corpus`) · 20 min
1. Apunta tus cifras de iCloud; desinstala e instala.
2. «Ya tengo una cuenta» › «Restaurar desde iCloud» › «Empezar desde cero» › confirmar → sale una puerta con cifras que casan y tres salidas, no el onboarding. De paso, si en «Encontramos tus datos» una tarjeta queda sola en su fila, mira si se ve bien.
3. «Traer mis datos» › Restaurar › «Continuar» → los datos vuelven completos.
4. Cierra y reabre un par de veces → siguen ahí.

### D4 · Sin card — «Vengo por un grupo» en un teléfono que ya tiene tus datos de iCloud (2 tickets) · 40 min
Tickets: `groups-entry-on-a-mirrored-store-still-blocks-the-owner` y `groups-only-second-launch-mounts-icloud-mirror`.
1. Borra Yala, reinstala, «Primera vez» › iCloud privado › «Restaurar mis datos» y deja que baje. Mata la app.
2. Vuelve al Welcome › «Vengo por un grupo» › «Crear mi primer grupo» → nada de «Aquí ya hay datos guardados»; sale «Estamos subiendo tus últimos cambios a iCloud…» y te pide reabrir.
3. Reabre → puerta de Grupos y sign-in sin elegir de nuevo; crea el grupo. Mata y abre tres veces → solo Grupos; nada de tus cuentas ni movimientos de iCloud.
4. Cierra la sesión de Grupos y reabre → nada del histórico.
5. Reinstala › «Ya tengo cuenta» › «Restaurar desde iCloud» → vuelve **todo** el histórico. Vacío es fallo grave.

### D5 · Sin card — «Activar Yala completo» pregunta dónde guardar tus finanzas (`full-mode-activation-must-ask-where-personal-data-lives`) · 30 min
1. Reinstala › «Vengo por un grupo» › crea un grupo y apunta un gasto tuyo y otro del otro miembro.
2. Perfil › «Activar Yala completo» → «¿Dónde guardamos tus finanzas?» con dos tarjetas.
3. «Tu cuenta en tu iCloud privado» → aviso con cifras y tres botones (restaurar, borrar, cancelar).
4. «Restaurar mis datos» › reabre › «Restaurar» › «Continuar» → tus datos de antes, con tu nombre y tu divisa.
5. Registros → cada gasto de grupo aparece una sola vez.

### D6 · Sin card — Cerrar la sesión privada no pierde lo que no subió (`session-exits-one-verb-per-session`) · 35 min
1. En la sesión privada, crea un gasto, espera 10 s y Perfil › «Cerrar sesión» → cierra sin aviso.
2. «Ya tengo cuenta» › «Restaurar desde iCloud» → todos tus datos, incluido ese gasto.
3. Modo avión, crea un gasto y cierra sesión → «Guardando tus cambios…» y, a los 45 s, un aviso con «1».
4. «Esperar» y quita el modo avión → cierra sola.
5. Repite el paso 3 y fuerza el cierre de Yala durante la espera → al reabrir, la sesión y los datos siguen ahí.

---

## E. Dos iPhone con la misma cuenta — 20 min

### E1 · `en-el-segundo-dispositivo-de-una-cuenta-gk5w` — Reintentar «Volver a iCloud» en el segundo iPhone · 20 min
El arreglo de servidor (g17_01) está aplicado en staging y producción desde el 9-oct.
1. Dos iPhone con la misma cuenta en la nube, los dos en modo nube.
2. En el primero, Perfil › «Dónde viven tus datos» › «Volver a iCloud» hasta terminar.
3. En el segundo, «Volver a iCloud» → sale la espera; cancélala.
4. Reintenta en el segundo → avanza. No debe salir «tu cuenta no lo permitía».

## F. iPad — nada

El único item de iPad, `ipad-soltar-un-pdf-o-imagen-ilegible-no-ti05`, pasó a done.

---

## G. Sin iPhone: consola y App Store Connect, antes de enviar — 45 min

### G1 · `el-esquema-de-icloud-del-repo-no-tiene-c-o2li` — Esquema de CloudKit de producción · 20 min · puede bloquear el envío
1. Abre `docs/cloudkit-schema-diff-2.1.md` y sigue su guía.
2. Sin cktool basta con mirar en Production que existen `CD_FavoritePayment.CD_amount` y `CD_Account.CD_accountNumber`.
3. Si faltan campos: impórtalos en Development y «Deploy Schema Changes». Solo altas: si sale Remove o Change, cancela.
4. Mira el tipo de `CD_CashFlowOverride.CD_line` y avisa a Frank para correr `PersonalCloudKitSchemaParityTests`.

### G2 · `el-manifiesto-de-privacidad-no-declara-l-kgqv` — Etiquetas de App Privacy · 15 min
1. Decide si fotos y audio van como vinculados al usuario (lo prudente) o no vinculados.
2. App Store Connect › App Privacy: copia la tabla del PR #446.
3. Xcode › Organizer › Privacy Report del archivo de 2.1, y compáralo con la tabla.

### G3 · `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f` — Claves del gateway · 10 min
1. Revoca la clave vieja de OpenAI.
2. Mira la caducidad de las claves gateway-staging y gateway-production.
3. Pasa a 1Password `~/Secrets/yala-gateway/{openai-staging.key, openai-prod.key, staging-dev-shared-secret}`.

`checklist-de-envio-de-2-1-a-app-store-ve-d0ui` sigue en qa: es tu lista del envío, no una prueba. Su PR #443 está en conflicto.

---

## Fuera de la tanda: no te toca

| Card / ticket | Por qué sigue abierto | Quién |
|---|---|---|
| `la-qa-nocturna-se-corta-por-tiempo-cada-7zso` | Van 2 de las 3 nocturnas que pide el ticket, verdes y con margen (9 y 10-oct). Falta medir la del 11-oct y el recuento de suites por tanda. | Frank |
| `scheduled-payments-notif-dedup` (sin card) | El resumen diario agendado no tiene evidencia. Se puede medir en simulador. | Frank |
| PR #427 (`crear-otra-cuenta-con-apple-entra-en-la-ni6g`) y PR #443 (`checklist-de-envio-…-d0ui`) | En cola de auto-merge pero en **conflicto** (DIRTY): no van a entrar solos. | Frank, o la sesión de cada uno |
| `decidir-que-hacer-con-lo-que-llega-a-icl-kyys` → backlog | El canario está en 2.1 y solo mide. Su device-QA pedía dos Apple ID y un iPhone sin iCloud. El número lo dará la flota tras el lanzamiento, y con él decides la política. | Tú, tras el lanzamiento |

---

## Lo que pasó a done

| Card | Ticket | Motivo |
|---|---|---|
| `ui-tres-tests-de-la-suite-advisory-falla-wsc6` | Tres XCUITest de la suite advisory fallan en los tres reintentos (`advisory-ui-tests-fail-every-retry`) | Es CI: los tres tests persistentes pasan 9/9 con -test-iterations 3 (EdgeCasesUITests.test_extremeMinimumAmountSaves), la decisión nueva la fija SetupChecklistManagerTests y las nocturnas del 9 y del 10-oct salieron verdes; no necesita a Jürgen. |
| `los-comentarios-de-ia-de-insights-y-del-0olr` | Los comentarios de IA de Insights y del flujo de caja no siguen el idioma de la app (`ai-comments-ignore-the-app-language`) | El banco de IA da 100 % en 14 idiomas en las tres tareas (gateway/bench/results/2026-10-07-idioma) e InsightsResponseLanguageTests fija la petición real; no toca dinero ni datos. |
| `decidir-ofrecer-cerrar-la-sesion-privada-186u` | Tras una migración fallida, el cambio de Apple ID no se detecta hasta pulsar «Reintentar» (`apple-id-change-check-stays-off-after-a-failed-migration`) | La migración fallida no se provoca a mano (techo de 15 min o 72 h); la cubren el XCUITest SessionExitsPerCellUITests con el seam -uitest-migration-failed y AppleIDChangeFailedMigrationCloseTests con un mutante por término. El guion de iPhone era opcional. |
| `al-archivar-una-cuenta-sigue-contando-en-fmiy` | Las cuentas archivadas siguen sumando al saldo total del Panel (`archived-accounts-still-count-in-the-panel-total`) | No calcula importes nuevos (reusa «Excluir de estadísticas»); lo cubren PanelTotalAccountsLogicTests y el XCUITest AccountsCrudUITests.test_archivingAccount_turnsOnExcludeAndShowsNotice, que recorre el flujo real. |
| — | Un gasto guardado desde el chat sumaba al saldo de la cuenta (`chat-draft-drops-the-expense-sign`) | ChatDraftSignedAmountTests guarda por saveDraft y comprueba que el saldo calculado sobre el store baja, con control por mutación; el arreglo lleva un mes en 2.1 y el QA del chat lo vuelve a ver al guardar. |
| — | Un movimiento del chat podía quedar en una divisa distinta a la de su cuenta (`chat-draft-stamps-its-own-currency-not-the-account`) | ChatDraftAccountCurrencyTests con 7 mutantes rojos, incluida la coherencia del tipo de cambio; la parte visible la mira el paso 3 del QA de la tarjeta del chat. |
| `todo-sincronizado-aparece-con-cambios-to-hx45` | «Dónde viven tus datos» dice «Todo sincronizado» con cambios que aún no subieron (`cloud-sync-status-says-all-synced-with-changes-still-pending`) | Solo cambia un texto de estado; SyncStatusSectionLogicTests prueba las dos direcciones con recuento sobre store real y plurales en 16 idiomas, con control rojo. |
| — | El hero del Panel llega a Estadísticas y a Distribución (`distribution-subviews-miss-the-new-panel-hero`) | Lo cubre el XCUITest StatisticsHeroLikePanelUITests y Jürgen ya vio el hero nuevo en su iPhone (reporte del hueco del 10-oct, arreglado en el PR #449); ninguna cifra cambia. |
| `tras-salir-de-un-adopt-cancelar-del-avis-fspw` | Tras salir de un adopt, «Cancelar» en «¿Borrar todo y continuar?» vuelve a la bienvenida (`fresh-start-alert-cancel-after-an-adopt-exit-lands-in-the-app`) | Es navegación y no borra nada; dos XCUITest de WelcomeFreshStartAlertUITests ejercitan el aviso y sus botones de producción con el seam -uitest-welcome-after-adopt-exit. El QA del ticket hermano lo vuelve a mirar de paso. |
| `mejorar-vistas-del-registro-en-grupos-ix2y` | Rediseño del detalle y la edición de un gasto de grupo (`group-expense-views-redesign`) | Jürgen aprobó el rediseño sobre capturas (propuesta B «con aire», 2026-10-04); la lógica de reparto no cambia y GroupsSmokeUITests fija el flujo. |
| `decidir-un-telefono-con-la-hora-adelanta-4nvh` | Un teléfono con la hora adelantada ya no gana todos los conflictos de sus grupos (`groups-clock-ahead-wins-every-conflict-until-real-time-catches-up`) | Evidencia fuerte de servidor: banco qa/cloud/hlc01-cap-test.sh 33/33 con la función real y 9 mutantes, sonda de staging 4/4 y migración hlc01 aplicada en staging y producción el 2026-10-07; un teléfono con la hora adelantada es un caso remoto. |
| — | Borrar un movimiento conservado al desasociar Grupos lo devuelve al circuito normal (`groups-detach-ledger-has-no-exit`) | Edge case remoto (desasociar, conservar, reasociar y borrar a mano) con evidencia fuerte: GroupsDetachedLedgerExitTests, 18 casos contra el bridge real con stores en disco y 14 mutantes muertos. |
| `grupos-con-el-drain-atascado-vuelve-cerr-g7qi` | Con la subida de Grupos atascada, vuelve «Cerrar sesión y perderlos» (`groups-drain-that-always-aborts-takes-the-loss-exit-away`) | El atasco solo se provoca con un fallo inyectado; lo fijan GroupsStuckDrainLossExitTests y FreshStartGroupsLossExitTests, y el guion de iPhone solo miraba caminos que no cambiaron. |
| `decidir-empezar-de-cero-en-la-bienvenida-cba9` | Los grupos que conserva el aviso tardío ya no se borran al cancelar el onboarding y empezar de cero (`groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start`) | Edge case remoto (aviso tardío + cancelar + elegir privado) de prioridad baja; el cambio solo quita un borrado, lo cubre el XCUITest WelcomeLateNoticeKeptGroupsUITests y la card ya marcaba el QA como opcional. |
| `estadisticas-de-un-grupo-no-deduplica-ga-8lui` | Las Estadísticas de un grupo cuentan cada gasto una sola vez (`groups-stats-no-deduplica-gastos`) | Un duplicado por id solo lo crea un merge del sync y no se provoca a mano; GroupStatsViewModelTests (5 nuevos, rojos con el código viejo: 2.630 frente a 2.150) y un mutante fijan que el total cuadra. QA marcado opcional. |
| `grupos-texto-propio-cuando-el-drain-se-a-vns8` | Con la subida de Grupos atascada en un teléfono sano, el aviso ya no promete que esperar lo cura (`groups-stuck-drain-on-a-healthy-phone-says-try-again-later`) | Solo cambia un texto, en un estado que no se provoca sin fallo inyectado; lo fija GroupsStuckDrainHealthyPhoneCopyTests en 16 idiomas. |
| `grupos-los-ajustes-del-grupo-recalculan-ha2m` | Grupos: los recálculos se agrupan y la lista ya no rehace las cuentas en cada tecla (`groups-tab-missing-panel-perf`) | Rendimiento puro: RecalculationDebouncerTests y GroupsCoalescedRecalculationTests (104 tests, 18 mutantes muertos) fijan el freno; el guion de dos aparatos se leía en la consola de Xcode, no es validación de Jürgen. |
| `la-lectura-de-imagen-pone-en-la-nota-tex-tkun` | La lectura de imagen pone el comercio en la nota, no el texto del banco (`image-note-uses-bank-template-instead-of-merchant`) | El banco de IA alcanza: 24/24 alertas de banco con la nota limpia, el caso de Grok incluido, sin empeorar importe, fecha ni divisa (gateway/bench/results/2026-10-10-nota-despues-v2/REPORT-nota.md). |
| `ipad-soltar-un-pdf-o-imagen-ilegible-no-ti05` | Soltar en iPad un PDF o una imagen ilegible no hace nada (`ipad-drop-unreadable-file-fails-silently`) | Prioridad baja y cubierto por ReceiptDropHandlerTests y el XCUITest ReceiptDropUITests, que suelta por el manejador real. |
| `decidir-borrado-de-icloud-pendiente-al-p-3fwt` | Un borrado de iCloud pendiente se olvida sin avisar si el dispositivo pasa a la nube (`late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`) | El estado real (borrado de iCloud atascado al activar la nube) es muy difícil de provocar y el guion admite que puede no salir; el diálogo lo cubre el XCUITest PendingICloudWipeMigrationUITests y el cambio solo pregunta o aplaza un borrado, nunca borra más. |
| `el-panel-no-recalcula-al-llegar-tasas-nu-t72p` | Cuando llegan las tasas del día, el Panel sigue enseñando las de ayer (`panel-no-recalcula-al-llegar-tasas-nuevas`) | No cambia cómo se calcula el saldo, solo cuándo; PanelWakesOnNewRatesTests y PanelApproximateMarkClearsTests salen rojos con el código viejo, y el estado depende de que iOS no mate la app de noche. |
| `decidir-un-telefono-con-la-hora-adelanta-4nvh` | Un teléfono que tuvo la hora adelantada gana los conflictos de tus datos en la nube (`personal-clock-ahead-wins-every-conflict-until-real-time-catches-up`) | Evidencia fuerte de servidor (banco 33/33, sonda de staging 4/4, migración hlc01 aplicada en producción el 2026-10-07) y ClockAheadServerCapTests en el cliente; adelantar la hora de un iPhone es un caso remoto. |
| `decidir-una-subida-que-siempre-aborta-de-1r4e` | Si el teléfono nunca consigue guardar, cerrar sesión en la nube dice «espera unos segundos» para siempre (`personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy`) | El caso no se provoca sin fallo inyectado; lo fijan CloudStuckDrainPersonalLossLogicTests y los signOutPushAll_* de CloudSyncRuntimeTests, y el cierre normal se ve en cualquier otro QA de nube. |
| — | Cerrar la sesión privada no comprobaba si había un paso de datos a la nube en marcha (`private-sign-out-proceeds-with-a-migration-in-flight`) | Solo bloquea un cierre que borraba; lo fijan PrivateSignOutMigrationGuardTests y el XCUITest SessionExitsPerCellUITests con el seam -uitest-migration-journal-unreadable. Montar una subida en vuelo a mano es difícil. |
| `en-un-registro-nuevo-cuenta-etiquetas-y-xs4y` | En un registro nuevo, cuenta, etiquetas y subcategoría abren a media altura (`record-selectors-open-at-medium-detent`) | Medido en simulador con capturas antes y después (PR #349) y fijado por el XCUITest TransactionsCrudUITests.test_recordSelectorsOpenAtMediumDetent; la card ya era de Frank. |
| — | Volver a Yala se parece demasiado a instalarla por primera vez (`reentry-counts-as-fresh-install`) | Lo pendiente es cosmético (banner, checklist y oferta) y lo fijan EntryOnboardingEffectsTests con mutantes; el QA de la sesión de la persona anterior hace el mismo recorrido. |
| — | Restaurar dice «no hay datos» cuando la búsqueda de iCloud se agotó, y ofrece borrar sin preguntar (`restore-says-no-data-when-the-icloud-import-never-settled`) | Solo añade una confirmación y un texto que no niega datos: reduce el riesgo de borrado. Montarlo pide dos Apple ID y red degradada; RestoreImportSettlementTests y RestoreStartFreshGateTests con mutantes. La puerta se ve en el QA de restore-start-fresh-keeps-the-imported-corpus. |
| — | «No encontramos tus datos» a quien solo tiene presupuestos en iCloud (`restore-treats-budgets-and-groups-as-no-data`) | La lógica la fijan RestoreDataPresenceWiringTests e ICloudAccountSummaryTests con 21 mutantes y no borra nada; la quinta tarjeta se ve de paso en el QA de restore-start-fresh-keeps-the-imported-corpus. |
| `decidir-el-plazo-y-el-texto-de-la-vuelta-fdwb` | Si la vuelta a iCloud no puede leer tus tablas, espera el plazo largo antes de rendirse (`reverse-upload-unreadable-sample-waits-the-long-ceiling`) | La base ilegible no se provoca a mano; la cubren MigrationRunnerTests §13-ter y ReverseUploadCeilingLogicTests, y la vuelta normal se ve en el QA de reverse-cutover-cerrado-para-cuentas-born-cloud. |
| — | Guardar una transacción desemparejada la reetiquetaba sin convertir el importe (`saving-a-mismatched-transaction-relabels-it-without-converting`) | Ninguna ruta ni seed crea hoy una fila desemparejada; MismatchedTransactionSaveTests (rojo con el guardado viejo) fija que se conserva importe y divisa, como prevé el propio ticket. |
| `tu-segundo-iphone-no-puede-activar-la-nu-w7w8` | El segundo iPhone del mismo iCloud no puede activar la nube hasta que le llega la marca del primero (`settings-migrate-blocks-a-second-device-before-its-marker`) | Solo cambia el texto de un bloqueo que ya existía: StorageMigrationIdentityGateLogicTests fija que ninguna cuenta recibe una migración nueva y el gateway tiene humo en staging y producción; la carrera con dos iPhone es muy difícil de montar. |
| `los-gastos-compartidos-planificados-apar-qo5b` | Los gastos compartidos planificados aparecen dos veces en la Bandeja (`shared-scheduled-expense-shows-twice-in-inbox`) | GroupScheduledExpenseSingleDraftTests reproduce el doble borrador (rojo en 2.1, verde con el arreglo) y el barrido de lo viejo es idempotente y con control; Jürgen lo verá en su uso diario. |
| `con-la-app-en-aleman-o-polaco-las-sugere-aq9g` | Las sugerencias del chat en alemán, polaco o inglés caen siempre a las fijas (`suggestions-rewriter-drops-german-and-polish-rewrites`) | Validador puro cubierto por SuggestionsRewriterServiceTests y por el banco con el modelo de producción (alemán 6/6, polaco 9/9, 0 sugerencias inventadas). |
| `tendencias-el-numero-grande-se-queda-con-dcj1` | El número grande de Tendencias se queda con el período anterior al cambiarlo desde Tendencias (`trends-hero-keeps-the-previous-period-after-changing-it-on-trends`) | El cálculo no cambia, solo cuándo se dispara; cifras medidas antes y después en simulador, iguales a Resumen, y StatisticsRecalculationTests y StatisticsHeroLikePanelUITests estaban rojos con la puerta vieja. |
| `trend-insight-card-v2-bullets-al-final-d-xm48` | Tarjeta de análisis de Tendencias V2: una frase por gráfica, en viñetas (`trends-insight-card-v2-bullets`) | Las viñetas por reglas las cubre TrendsInsightCardUITests y la respuesta real de la IA pasó el banco al 100 % con el cuerpo exacto de la app; lo que queda (regenerar, sin red, AX5) es de riesgo bajo. |
| `voz-5000-pesos-en-argentina-sale-en-otra-cs7q` | La lectura de una nota de voz solo conoce seis divisas y no sabe cuál es la del usuario (`voice-note-parser-prompt-knows-six-currencies`) | El banco con el modelo de producción da 102/102 sobre los mismos casos del guion, con control rojo (50 % con el prompt viejo), y TranscriptionParserCurrencyTests fija que la petición real lleva la divisa. |
| `voz-5000-pesos-en-argentina-sale-en-otra-cs7q` | El parser de voz y chat pide JSON solo por texto, y su prompt se contradice (`voice-parser-sends-no-json-mode`) | Estructura de respuesta del gateway, medida con el banco en producción (0 respuestas ilegibles en 102); una respuesta mal formada no se provoca a mano. |
| `decidir-el-texto-del-dialogo-de-cancelar-p4bk` | Al cancelar la entrada a tu cuenta desde la bienvenida, el diálogo dice «desde aquí» (`welcome-adopt-cancel-dialog-says-from-here`) | Cambio de texto fijado por WelcomeAdoptExitTests en las 8 combinaciones y en los 16 idiomas; montarlo pide cancelar a tiempo con una cuenta real y red lenta. |
| `el-texto-de-vaciar-datos-y-lo-que-se-bor-bsvw` | «Vaciar datos» promete menos de lo que borra en una de las cuatro celdas (`wipe-copy-reads-one-axis-while-the-sheet-reads-two`) | Solo cambia de dónde sale un texto, no qué se borra; la única celda que cambia no se monta a mano y la cubre WipeDescriptionParityTests con control rojo. |
| — | «Vaciar datos» conserva los grupos pero se lleva sus gastos y liquidaciones de lo personal (`wipe-data-keeps-groups-but-drops-their-bridged-rows`) | GroupsBridgeRestoreConvergenceBehaviourTests corre contra el bridge real y el wipeAllUserData real, con mutantes; el QA era opcional y obligaba a vaciar un iPhone. |
| `revisar-el-uso-de-ia-modelos-coste-y-res-v6or` | Revisar el uso de IA: modelos, coste y respuestas (sin ticket en qa) | No pedía QA: el informe y los 18 tickets entraron con el PR #385, y la decisión de gpt-4.1-nano ya está cerrada (`gpt-4-1-nano-shuts-down-on-october-23` en done). |
