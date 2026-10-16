# Tanda de QA de Jürgen — 2.1

Barrido del 2026-10-16 con `/barrido-qa`, sobre `origin/2.1` en `c648223bc` (#526). El #527 (Novedades) estaba en cola de auto-merge: su hoja sale de sus
capturas. Sustituye al del 15-oct (#514):
recoge lo que entró después (#515 a #527) y saca de la tanda lo que ya cerraste tú el 15-oct.

- **Revisado:** las 23 cards de 2.1 (16 «in qa», 2 «blocked» y 5 de backlog), los 25 tickets de `tickets/qa/` y los
  PRs #515 a #527.
- **Pasan a done:** 1 card y 3 tickets.
- **Probado en el simulador:** 3 pruebas, con la evidencia en `~/Claude/worktrees/_capturas/2026-10-16-barrido-qa-2-1-2/`.
  Ninguna falló.
- **Pasan a 2.2:** 2 cards.
- **Se quedan para tu iPhone:** 19 pruebas en 4 bloques. **Sin iPhone:** 6. **Para aprobar con capturas:** 2 pantallas.
- **Tiempo total estimado: unas 7 h 15 min** (iPhone 6 h, sin iPhone 1 h 10 min, capturas 5 min). Lo que bloquea el
  lanzamiento suma **3 h 50 min**.

Los ids de card van sin el prefijo `tablero-`. Cada prueba dice qué la retiene: §4 es «solo en un iPhone real» y §5 es
«tu visto bueno».

## Antes de empezar

1. **El esquema de iCloud va antes que el TestFlight.** Despliega el campo nuevo del flujo de caja (E · esquema, abajo)
   **antes** de instalar el 17 en ningún iPhone. Si el build llega antes, los ajustes de un mes siguen sin sincronizar.
2. **El TestFlight 17 ya está subido** (16-oct, 2.1 (17), desde `2.1` en `55c473e03`, con el #527 dentro) y disponible
   para pruebas internas. El TestFlight 16 (12-oct) no lleva nada de lo que entró desde el #514. Los bloques B, C y D
   van con el 17.
3. **El bloque A va con Yala Dev compilado desde ese mismo `2.1`**, contra staging.
4. **Guarda dos instalaciones viejas:** un iPhone con el **TestFlight 16** para C · D2, y el iPhone A del bloque D con
   **Yala 2.0.4 de la App Store** para D · ly22. No las actualices antes de llegar a esas pruebas.
5. **Archivos de prueba** en `~/Claude/entregas/qa-guiado-2-1/`: el CSV de 1.500 movimientos para A · C1 está en
   `2-para-Archivos/`. Pásalo por AirDrop.

## Qué bloquea el lanzamiento

Si una falla, 2.1 no sale: se pierden datos, un usuario nuevo no puede entrar o Apple rechaza el envío.

| # | Prueba | Card / ticket | Min |
|---|---|---|---|
| 1 | E · esquema · El campo nuevo del flujo de caja en iCloud | `los-ajustes-de-un-mes-del-flujo-de-caja-ly22` | 15 |
| 2 | E · G1 · Etiquetas de App Privacy | `el-manifiesto-de-privacidad-no-declara-l-kgqv` | 15 |
| 3 | E · G2 · La ficha cuenta la nube | `la-web-la-politica-y-la-ficha-dicen-que-i6tj` | 5 |
| 4 | E · G3 · Checklist de envío | `checklist-de-envio-de-2-1-a-app-store-ve-d0ui` | 15 |
| 5 | E · gateway · «Eliminar mi cuenta» borra el contador | `desplegar-el-gateway-eliminar-mi-cuenta-z9uu` | 10 |
| 6 | A · i1o5 · Apagar iCloud Drive no ofrece borrar | `apagar-icloud-drive-hace-que-yala-diga-t-i1o5` | 5 |
| 7 | A · C1 · Activar la nube con muchos movimientos | `snapshot-upload-has-no-ceiling-and-no-way-out` | 20 |
| 8 | A · 4nt6 · «Volver a iCloud» con datos viejos en ese iCloud | `volver-a-icloud-con-una-cuenta-nacida-en-4nt6` | 20 |
| 9 | C · D1 · «Primera vez › privado» mira iCloud | `welcome-private-fresh-start-skips-icloud-check` | 20 |
| 10 | C · D2 · Actualizar encima no cierra la sesión | `previous-person-cloud-session-survives-…` | 10 |
| 11 | C · D3 · «Vengo por un grupo» con datos de iCloud | `groups-entry-on-a-mirrored-store-…` (2 tickets) | 40 |
| 12 | D · E1 · Unirse a un grupo con dos iPhone | `validar-en-testflight-unirse-a-un-grupo-e1ah` | 30 |
| 13 | D · ly22 · Los ajustes del flujo de caja viajan | `los-ajustes-de-un-mes-del-flujo-de-caja-ly22` | 25 |

**Orden:** el bloque E primero (no pide iPhone, y el esquema tiene que estar antes del TestFlight 17). Luego los bloques
A, B, C y D.

---

## A. iPhone de QA con Yala Dev contra staging — 1 h 35 min

Yala Dev compilado desde `2.1` con #527. Empieza con una sesión **privada** con datos (al menos 20 movimientos).

### A · i1o5 — Apagar iCloud Drive no dice que tus datos se borraron · 5 min · **bloquea** · §4 iCloud real
Card `apagar-icloud-drive-hace-que-yala-diga-t-i1o5` (#515). El simulador no tiene iCloud: ahí ya sale el aviso nuevo,
pero no se puede apagar Drive con datos ni ver la reimportación.
1. Apunta cuántos movimientos tienes. Ajustes del iPhone › tu nombre › iCloud › iCloud Drive: apágalo.
2. Abre Yala y espera 10 s → «iCloud no está disponible en este dispositivo», con un solo botón, «Entendido». **No**
   debe salir «Tus datos fueron eliminados» ni «Empezar de cero». Toca «Entendido».
3. Enciende iCloud Drive y reabre Yala → los movimientos vuelven solos, y mientras vuelven no sale ningún aviso de
   borrado.

### A · vb1f — Entrar con Google cuando este iPhone ya tiene cuenta con Apple (parte C) · 5 min · §4 inicio de sesión real
Card `entrar-con-google-cuando-este-iphone-ya-vb1f`. La parte A ya pasó en el simulador.
Montaje: el Apple ID del iPhone con una cuenta de Yala creada con Apple, y una cuenta de Google **sin** cuenta en Yala.
1. Borra Yala Dev y vuelve a instalarla. «Ya tengo una cuenta».
2. «Entrar con Google» › consentimiento › la cuenta de Google sin Yala → «Esa cuenta usa otro método».
3. Toca **«Crear cuenta con Google»** → consentimiento. **No** debe volver a salir la hoja de Google, y sigue al
   onboarding. Si vuelve a salir, avisa a Frank: el servidor rechazó la credencial reusada.

### A · C6 — El consentimiento de Grupos queda registrado · 15 min · §4 inicio de sesión real
Ticket `groups-consent-door-spec`.
1. Instalación nueva con una cuenta Apple o Google de pruebas: «Vengo por un grupo» › «Crear mi primer grupo» →
   explicación › entrar › «Grupos en la nube» › «¿Cómo te llamas?».
2. «Aceptar y continuar», pon tu nombre y crea un grupo.
3. Avisa a Frank: comprueba en staging que hay **una** fila de consentimiento de esa cuenta.
4. Perfil › «Cerrar sesión» y vuelve a entrar por «Vengo por un grupo» con la misma cuenta → no vuelve a salir «Grupos
   en la nube», y sigue habiendo una sola fila.

### A · dzih — Un alta de Grupos a medias no se confunde con datos ajenos · 10 min · §4 inicio de sesión real
Card `un-alta-de-grupos-a-medias-llega-al-avis-dzih`, ticket `groups-entry-left-half-done-reaches-the-private-gate-with-group-rows`
(#522). Va justo después de C6: usa esa misma cuenta de solo grupos, que ya tiene un grupo. Bajo XCUITest este camino
no se puede conducir; la cadena de decisiones la fija un test.
1. Borra Yala Dev y reinstala. «Ya tengo una cuenta» › entra con la cuenta de C6.
2. En Grupos, vuelve atrás **sin** terminar el alta.
3. Manda Yala a segundo plano unos segundos y vuelve.
4. «Es mi primera vez en Yala» › «Tu cuenta en tu iCloud privado» → **no** debe salir «Ya hay datos en este teléfono».
5. Termina el onboarding → tu grupo sigue en Grupos.

### A · C1 — Activar la nube con muchos movimientos · 20 min (casi todo espera) · **bloquea** · §4 sesión real e iCloud
Ticket `snapshot-upload-has-no-ceiling-and-no-way-out`. Los techos, el modo avión al 55 % y «Cancelar la activación» ya
los fijan los tests (22 mutantes). Falta ver que el techo no salta en una subida larga de verdad.
Montaje: Yala Dev en modo privado con datos y una cuenta de staging **nueva**.
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

### A · 4nt6 — «Volver a iCloud» avisa si ese iCloud ya tiene datos de Yala · 20 min · **bloquea** · §4 iCloud real
Card `volver-a-icloud-con-una-cuenta-nacida-en-4nt6`, ticket `reverse-to-icloud-merges-prior-icloud-data-without-asking`
(#517). Las ramas de la decisión las fijan 33 unitarios, 7 XCUITest y 11 mutantes; falta la pregunta y el borrado
contra un iCloud de verdad. Tras C1 y C4 el iCloud de este iPhone ya tiene datos de Yala de otra cuenta: es el montaje.
Necesitas dos cuentas de Google **nuevas** (A y B).
1. Perfil › «Cerrar sesión». En la bienvenida: «Es mi primera vez en Yala» › «Tu cuenta en la nube» › Google A. Crea 2
   movimientos.
2. Perfil › «Dónde viven tus datos» › «Volver a iCloud» → «Revisando tu iCloud…» y luego «Tu iCloud ya tiene datos de
   Yala», con cifras.
3. «Sumarlos a mis datos» › confirma. Al terminar, en Registros están tus 2 y los de antes.
4. «Cerrar sesión» › «Es mi primera vez en Yala» › «Tu cuenta en la nube» › Google B. Crea 1 movimiento.
5. «Volver a iCloud» → el aviso sale otra vez.
6. «Empezar sin ellos» › «Borrar y volver a iCloud».
7. Al terminar, en Registros y en la Bandeja: solo el movimiento de B, ningún gasto de grupo.
8. Si en el paso 2 sale siempre «No pudimos revisar tu iCloud» con buena red, avisa: es el único punto que no se pudo
   medir.

---

## B. Cámara y micrófono, con Pro — 20 min

TestFlight 17 o Yala Dev. El simulador no tiene cámara, y en la Mac sin micrófono no se puede dictar. Las pantallas ya
las aprobaste el 15-oct; aquí solo queda lo que pide el hardware. Cualquier uso de la IA de este bloque con el TestFlight
17 prueba además App Attest en producción.

### B · cámara — Registro por foto con la cámara · 5 min · §4 cámara
Card `mejorar-el-registro-por-imagen-de-punta-g5wl`, ticket `image-entry-end-to-end-redesign`.
1. Panel › botón de imagen › «Cámara» (la primera vez acepta el permiso) y fotografía un recibo → «Leyendo tu foto…» y
   luego «Esto leí».
2. Ajustes de iOS › Yala › Cámara apagada. Vuelve y toca «Cámara» → «Yala no puede usar la cámara» con «Abrir
   Configuración». Vuelve a encenderla.

### B · micrófono — Voz, dictado del chat e idioma de voz · 15 min · §4 micrófono
Card `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f`; tickets `voice-entry-end-to-end`, `chat-dictation-looks-poor` y
`ai-every-call-sends-its-task-and-passes-the-bench`. La voz es la segunda tarjeta de las Novedades de 2.1.
1. Panel › icono de onda (Voz) → la hoja ya escucha (la primera vez iOS pide el micrófono). Habla normal y luego fuerte:
   el halo crece con la voz.
2. Di «taxi 12 y café 8» › «Listo» → dos filas, y «Guardar 2» registra las dos.
3. Con música en otra app, abre Voz y toca «Cancelar» → la música vuelve a sonar.
4. Con modo avión, toca Voz → «Sin conexión» con «Usar imagen» y «Volver a grabar». Quita el modo avión.
5. Yala IA › micro → «Escuchando…». Di «gasté 25 en el almuerzo con la tarjeta» › «Listo» → el texto queda en la caja,
   sin enviarse.
6. Perfil › Personalización › «Idioma de voz» → «Idioma de la app» y los 10 idiomas. Elige English, dicta en Voz «Coffee
   4.50 at Starbucks» → borrador de 4,50. Vuelve a «Idioma de la app».

---

## C. TestFlight 17 con tu Apple ID — 2 h 35 min

Un iPhone de pruebas con tu Apple ID: estas pruebas leen tus datos reales de iCloud y solo TestFlight ve ese contenedor.
Ninguna borra iCloud salvo que lo elijas. Todas son §4 (iCloud real; D2, además, actualizar encima).

### C · D1 — «Primera vez › privado» mira iCloud antes de empezar · 20 min · **bloquea**
Ticket `welcome-private-fresh-start-skips-icloud-check`. Sin iCloud ya pasó en el simulador.
1. Apunta cuántos movimientos y cuentas tienes, y el mes del más antiguo. Desinstala e instala Yala.
2. «Es mi primera vez en Yala» › «Tu cuenta en tu iCloud privado» → «Revisando qué hay en tu iCloud…» y luego un aviso
   con cifras que casan con lo apuntado.
3. Si en cambio sale siempre «No pudimos conectarnos a iCloud», para: es el fallo que bloquearía a todo usuario nuevo.
4. Toca volver → regresas a la elección. Entra otra vez por privado → mismas cifras; «Traer mis datos».

### C · D2 — Actualizar encima no cierra la sesión · 10 min · **bloquea**
Ticket `previous-person-cloud-session-survives-fresh-start-and-reinstall`.
1. Con el **TestFlight 16**, entra con una cuenta de nube de prueba y crea un grupo → Perfil › «Dónde viven tus datos»
   muestra su correo.
2. Instala el TestFlight 17 **encima**, sin borrar → la sesión sigue abierta y Grupos entra sin pedir nada.
3. Borra Yala y reinstala → la bienvenida de instalación nueva; «Ya tengo una cuenta» pide elegir y no entra solo.
4. Entra con la cuenta de prueba → recupera sus grupos.

### C · D3 — «Vengo por un grupo» en un teléfono con tus datos de iCloud · 40 min · **bloquea**
Tickets `groups-entry-on-a-mirrored-store-still-blocks-the-owner` y `groups-only-second-launch-mounts-icloud-mirror`.
1. Borra Yala, reinstala, «Es mi primera vez en Yala» › iCloud privado › «Traer mis datos» y deja que baje. Cierra Yala
   del todo.
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

## D. Dos iPhone — 1 h 30 min

ly22 y E3 piden el **mismo Apple ID** en los dos y van seguidas. E2 pide la misma cuenta en la nube en los dos. E1 pide
dos cuentas distintas. Todo con el TestFlight 17: un build de Xcode da 401 contra producción. Las cuatro son §4 (dos
dispositivos físicos).

### D · ly22 — Los ajustes de un mes del flujo de caja viajan al otro iPhone · 25 min · **bloquea**
Card `los-ajustes-de-un-mes-del-flujo-de-caja-ly22`, ticket `personal-cloudkit-cashflow-override-line-declared-as-reference`
(#523). Con E · esquema ya hecho. La migración la fijan los tests; falta el viaje real por iCloud. De paso, prueba
también las Novedades de 2.1 (card `novedades-de-2-1-en-la-app-h4hj`, §4 actualizar encima).
1. iPhone A, todavía con **Yala 2.0.4 de la App Store**: pestaña «Más» › «Flujo de caja», toca la celda de un mes de una
   línea, pon 1.111 y «Guardar ajuste». Si no ves «Flujo de caja», apaga «Solo gastos» en Personalización.
2. Instala el TestFlight 17 encima en A, y también en B.
3. Abre A → sale «Mira lo nuevo en Yala» con «Grupos», «Anotar nunca fue tan fácil» y «Tus datos, tus reglas». Lee el
   texto en español y toca «Continuar». Cierra Yala del todo y reábrela → la hoja no vuelve.
4. Abre B › «Más» › «Flujo de caja» → en uno o dos minutos (o al reabrir) ese mes enseña 1.111. **Si no llega, no
   publiques:** el build no arregla los ajustes que ya había.
5. En A, ajusta otro mes a 1.234 › en B aparece. En B cámbialo a 2.000 › en A aparece.

### D · E3 — Un ajuste viaja al otro iPhone · 15 min
Card `las-preferencias-se-volvian-a-guardar-so-d44s` (blocked), ticket `tickets/blocked/apppreferences-rewritten-on-launch.md`.
Va después de ly22: «Solo gastos» esconde el flujo de caja.
1. iPhone A: Perfil › Personalización › activa «Solo gastos». A los pocos minutos, el iPhone B lo tiene activado.
2. iPhone A: concede el permiso de notificaciones desde el primer aviso → en el B, las alertas de presupuesto salen
   activadas.
3. Cierra Yala en el A. En el B, cambia la divisa principal. Abre el A → tiene la divisa nueva; abrirlo no la pisa.
4. Apaga «Solo gastos» otra vez.

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

---

## E. Sin iPhone: iCloud, App Store Connect, la ficha y el gateway — 1 h 10 min

### E · esquema — El campo nuevo del flujo de caja en iCloud · 15 min · **bloquea** · antes del TestFlight 17
Card `los-ajustes-de-un-mes-del-flujo-de-caja-ly22`. Runbook entero en `docs/cloudkit-schema-diff-2.1.md`, sección «El
campo nuevo de los ajustes del flujo de caja», pasos A a E.
1. CloudKit Console › `iCloud.com.jurgenschmidt.yala` › Development › Schema › Record Types › `CD_CashFlowOverride` ›
   añade el campo `CD_cashFlowLine`, tipo String › Save.
2. «Deploy Schema Changes…» a Production. La lista tiene que ser solo de altas; si sale un «Remove» o un «Change»,
   cancela.
3. Verifica con el export del paso C que Production tiene `CD_cashFlowLine STRING` y `CD_line REFERENCE`.
4. Lo mismo en `iCloud.com.jurgenschmidt.yala.dev` (paso D).

### E · gateway — «Eliminar mi cuenta» borra el contador de uso · 10 min · **bloquea**
Card `desplegar-el-gateway-eliminar-mi-cuenta-z9uu` (#519). La política ya dice que se borra.
1. `cd gateway && npm run deploy:staging`, y luego `npm run deploy:production` (pasos en `gateway/RUNBOOK.md`).
2. Borra una cuenta de prueba de staging y mira en `wrangler tail` que no sale «quota cleanup falló».

### E · G1 — Etiquetas de App Privacy · 15 min · **bloquea**
Card `el-manifiesto-de-privacidad-no-declara-l-kgqv`.
1. Decide si fotos y audio van como vinculados al usuario (lo prudente) o no vinculados.
2. App Store Connect › App Privacy: copia la tabla del PR #446.
3. Xcode › Organizer › Privacy Report del archivo de 2.1, y compáralo con la tabla. Deben coincidir.

### E · G2 — La ficha cuenta la nube · 5 min · **bloquea**
Card `la-web-la-politica-y-la-ficha-dicen-que-i6tj`, ticket `session-redesign-web-and-store-copy`. La política y los
términos ya están (#469), y la web ya no llama «Beta» a Grupos (#516, #525).
1. Pregunta a Lola si la ficha de los 7 idiomas ya dice que Grupos vive en la nube y si cambió la rama de producción de
   Vercel de `1.0` a `2.1`.
2. Con G1 hecho y la ficha al día, la card pasa a done.

### E · G3 — Checklist de envío · 15 min · **bloquea**
Card `checklist-de-envio-de-2-1-a-app-store-ve-d0ui`.
1. Abre `docs/RELEASE-CHECKLIST-2.1.md` y marca lo que ya está: la política (#469), el manifiesto (#446), los plist
   (#447) y el esquema de CloudKit (con E · esquema).
2. Repasa las casillas de fuera del repo: la app de Google en «Prueba», la URL de App Store Server Notifications y la
   rama de producción de Vercel.
3. Lo que siga sin marcar es lo que te queda antes de enviar.

### E · G4 — Claves del gateway · 10 min
Card `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f`.
1. Revoca la clave vieja de OpenAI.
2. Mira la caducidad de las claves gateway-staging y gateway-production.
3. Pasa a 1Password `~/Secrets/yala-gateway/{openai-staging.key, openai-prod.key, staging-dev-shared-secret}`.

---

## Para aprobar con capturas, sin iPhone — 5 min

Dos pantallas nuevas que funcionan en el simulador y que no has visto construidas. Si te convencen, sus cards pasan a
done; si no, dilo y sale un ticket de pulido. Todas en `~/Claude/worktrees/_capturas/2026-10-16-barrido-qa-2-1-2/`.

| Pantalla | Card | Capturas |
|---|---|---|
| Aviso «Movimientos sin cuenta» en el Panel y su hoja | `los-movimientos-que-quedaron-sin-cuenta-sovw` | `sovw-1…4` |
| «Mira lo nuevo en Yala» de 2.1 (texto en español) | `novedades-de-2-1-en-la-app-h4hj` | `h4hj-1` |

La de Novedades se cierra con esto y con el paso 3 de D · ly22.

---

## Fuera de la tanda

| Qué | Por qué | Quién |
|---|---|---|
| `declarar-el-entitlement-de-app-attest-de-g8rc` | Pasa a 2.2: solo falta el build Debug del scheme «Yala» desde Xcode, que no llega a ningún usuario. La ruta de TestFlight la prueba el bloque B. | — |
| `el-token-de-gestion-de-supabase-en-la-mi-bob7` | Pasa a 2.2: rotar el token no toca la app ni el envío. | Jürgen |
| `decidir-que-hacer-con-lo-que-llega-a-icl-kyys`, `dos-telefonos-con-el-mismo-ajuste-de-un-fqnc`, `un-ajuste-del-flujo-de-caja-que-llega-a-uk7h` | Backlog de 2.1 que se queda en 2.1 por el criterio del 15-oct (datos y sync), sin prueba en esta tanda. | Frank / Jürgen |
| Subir las capturas de la ficha a App Store Connect | Card 605d, de Lola. | Lola |
| Las 36 cards «in qa» de 2.2 | No son de 2.1. | — |

---

## Lo que pasó a done

### Cards

| Card | Motivo | Evidencia |
|---|---|---|
| `decidir-tras-cancelar-la-entrada-con-la-069g` | Decisión tomada (A) e implementada (#372); llegar al estado con un adopt real es casi imposible a mano | `WelcomeFreshStartAlertUITests` (5 casos, el de los cambios de grupos con mutante muerto en #518), re-corrido en el barrido |

Ya las habías cerrado tú el 15-oct al aprobar las capturas: `ofst`, `rdfd`, `apsc`, `u58k`; y `8xt4` (#518) y `sp9y`.

### Tickets

| Ticket | Motivo | Evidencia |
|---|---|---|
| `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes` | Igual que la card 069g | `WelcomeFreshStartAlertUITests` |
| `chat-draft-card-redesign` | Aprobaste la pantalla el 15-oct; lo funcional pasó en el simulador con staging | Capturas `b4-1…4` del barrido del 15-oct |
| `ai-chat-reads-heavier-than-a-messaging-app` | Aprobaste la pantalla el 15-oct | Captura `b4-1` del barrido del 15-oct |

### PRs desde el barrido del 15-oct que no te piden nada

| PR | Por qué no |
|---|---|
| #516, #525 | Web y textos: Grupos sin «Beta» en la política, la landing y el FAQ; tildes en francés. |
| #518 | Arreglo del montaje de test de C5; ver la card 069g arriba. |
| #519 | Ya en la app; solo falta desplegar el gateway (E · gateway). |
| #520 | Probado en el simulador (abajo); solo falta tu visto bueno al aviso. |
| #522 | La Bandeja y el aviso con filas de grupo, con XCUITest (`GroupRowsWithoutGroupUITests`); lo que pide iPhone es A · dzih. |
| #523 | La gráfica del Saldo, con tests contra la conversión día a día (card 502e en done); lo que pide iPhone es ly22. |
| #521, #524, #526 | Semillas y demos de la ficha: no cambian la app publicada. |

## Lo que se queda

| Card / ticket | Prueba | Qué lo retiene |
|---|---|---|
| `los-ajustes-de-un-mes-del-flujo-de-caja-ly22` · `personal-cloudkit-cashflow-override-line-declared-as-reference` | E · esquema y D · ly22 | Tu despliegue del esquema; §4 dos dispositivos |
| `apagar-icloud-drive-hace-que-yala-diga-t-i1o5` | A · i1o5 | §4 iCloud real (apagar iCloud Drive) |
| `volver-a-icloud-con-una-cuenta-nacida-en-4nt6` · `reverse-to-icloud-merges-prior-icloud-data-without-asking` | A · 4nt6 | §4 iCloud real y entrada real con Google |
| `un-alta-de-grupos-a-medias-llega-al-avis-dzih` · `groups-entry-left-half-done-reaches-the-private-gate-with-group-rows` | A · dzih | §4 entrada real con una cuenta de solo grupos |
| `novedades-de-2-1-en-la-app-h4hj` | Capturas + D · ly22 paso 3 | §5 la hoja nueva; §4 actualizar encima de la App Store |
| `los-movimientos-que-quedaron-sin-cuenta-sovw` · `records-orphaned-by-earlier-account-deletions-stay-invisible` | Capturas | §5 el aviso nuevo del Panel |
| `desplegar-el-gateway-eliminar-mi-cuenta-z9uu` | E · gateway | Despliegue tuyo |
| `entrar-con-google-cuando-este-iphone-ya-vb1f` | A · vb1f | §4 inicio de sesión real con Google |
| `groups-consent-door-spec` | A · C6 | §4 inicio de sesión real y la fila en staging |
| `snapshot-upload-has-no-ceiling-and-no-way-out` | A · C1 | §4 sesión real e iCloud |
| `tras-volver-a-icloud-un-movimiento-cread-amad` · `cloud-tx-epoch-orphan-relations` | A · C4 | §4 CloudKit real |
| `mejorar-el-registro-por-imagen-de-punta-g5wl` · `image-entry-end-to-end-redesign` | B · cámara | §4 cámara |
| `ia-sesion-2-la-app-manda-su-tarea-las-12-h52f` · `ai-every-call-sends-its-task-and-passes-the-bench` · `voice-entry-end-to-end` · `chat-dictation-looks-poor` | B · micrófono y E · G4 | §4 micrófono; las claves, sin iPhone |
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
| `release-plist-leftovers-widget-build-faceid-appattest` | Fuera (card g8rc en 2.2) | El build Debug de Xcode; no es de 2.1 |

## Probado en el simulador en este barrido

Yala Dev compilado desde `c648223bc`, iPhone 17 Pro con iOS 27.0. Capturas en
`~/Claude/worktrees/_capturas/2026-10-16-barrido-qa-2-1-2/`.

| Prueba | Esperado | Salió | Evidencia |
|---|---|---|---|
| sovw · Movimientos sin cuenta (semilla `movimientos-sin-cuenta`) | Aviso con un 2, la hoja los lista, mover los devuelve al saldo | Aviso «Movimientos sin cuenta · 2» con S/ 1.000; hoja con Taxi −25 y Teléfono −33; «Mover a «Banco QA»» deja S/ 942, Gastos S/ 58 y sin aviso; en Buscar, Taxi lleva «Banco QA» | `sovw-1…4`; `OrphanedRecordsUITests` 2/2 y `GroupRowsWithoutGroupUITests` 3/3 |
| 069g · «Borrar todo y continuar» tras salir de un adopt | Sin bucle; con cambios de grupos, oferta con su cifra y onboarding | Como se esperaba | `WelcomeFreshStartAlertUITests` 5/5 |
| h4hj · «Mira lo nuevo en Yala» | Tres tarjetas con tu texto exacto | El texto casa palabra por palabra con el del 16-oct | `h4hj-1` (captura del #527); `WhatsNewLaunchUITests` en el #527 |

## Encontrado en el barrido

- **El runbook del esquema mandaba a «Planificación → Flujo de caja».** En la app está en «Más › Flujo de caja», y
  con «Solo gastos» activado no aparece. Corregido en `docs/cloudkit-schema-diff-2.1.md` (paso F.1), y por eso D · ly22
  va antes de D · E3, que activa «Solo gastos».
- **Las cards de voz, dictado y tarjetas del chat se cerraron el 15-oct con sus tickets en qa.** Los dos de tarjetas
  pasan a done; los de voz y dictado siguen en qa colgados de h52f, porque el micrófono nunca se probó.
- Nada falló en el simulador: ninguna card de bug nueva.
