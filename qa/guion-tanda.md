# Guion de la tanda de QA

> **Qué es esto.** La cola de `tickets/qa/` y el guion para recorrerla en el iPhone, agrupada **por
> montaje** y no por ticket: una reinstalación sirve a tres tickets si se hacen seguidos.
>
> **Actualizado: 2026-10-04 · 36 tickets.** Sale del barrido antes del QA del lunes 5 de octubre (encargo
> `2026-10-04-barrido-qa-antes-del-qa-del-lunes`), con el criterio de #224 y #291. Desde el barrido del 28-sep
> la cola volvió a crecer de 23 a 51. **15 bajaron a `done` sin device-QA**: los 2 del CI, los 5 de iPad (lo que
> les falta solo existe en un iPad), 7 que piden dos dispositivos, SQL, tocar el gateway o una carrera que no se
> provoca a mano, y 1 `absorbed` cuya prueba ya es un paso de R11. Cada uno lleva al final su sección «Barrido de
> `qa` · 2026-10-04» con el porqué. **Entran
> 13**: casi todos son los rediseños de esta semana y van juntos en el **bloque R**. Los 23 del 28-sep
> siguen: nadie los ha probado todavía. **Los 36 de aquí son los que merece la pena probar a mano**; los que
> bajaron a `done` no se te vuelven a pedir.
>
> Al mover algo a `qa/` o sacarlo de ahí, actualiza este guion.
>
> `qa` NO significa «terminado»: significa que el código está hecho y verificado hasta donde el simulador
> alcanza.

## La lista corta

En el orden del guion. Una línea por ticket: qué pruebas y por qué no basta con los tests.

| # | Ticket | Qué pruebas | Por qué a mano |
|---|---|---|---|
| A0 | `onboarding-login-should-match-the-sep15-reference` | Las pantallas de «Empezar» y «Ya tengo una cuenta» con el diseño nuevo | Es lo primero que ve todo usuario; el aspecto no lo mide un test |
| A1 | `scheduled-payments-notif-dedup` | El resumen de pagos del día llega a su hora con la app cerrada, una sola vez | Lo reportaste tú en el iPhone, y las notificaciones reales no salen en el simulador |
| A2 | `chat-draft-drops-the-expense-sign` | Un gasto dictado al chat baja el saldo, no lo sube | Toca saldos de uso diario; el chat necesita App Attest y solo responde en el iPhone |
| A3 | `chat-draft-stamps-its-own-currency-not-the-account` | «50 dólares» sobre una cuenta en soles se guarda en soles | Mismo dictado que A2, un minuto más |
| A4 | `changing-an-account-currency-orphans-its-whole-history` | Cambiar la divisa de una cuenta pregunta y convierte todo su histórico | Es lo único de la app que reescribe importes ya guardados; el selector no responde a la automatización |
| A5 | `archived-accounts-still-count-in-the-panel-total` | Archivar una cuenta enciende «Excluir» y el total del Panel deja de sumarla | Toca la cifra que más miras; el aviso que sale debajo hay que leerlo |
| R1 | `distribution-subviews-miss-the-new-panel-hero` | La cabecera del Panel se repite igual en las cuatro pestañas de Estadísticas y en Pagos planificados | Rediseño de hoy; alineación y botones flotantes se juzgan a ojo |
| R2 | `trends-insight-card-v2-bullets` | El resumen de Tendencias en frases con viñeta, y el análisis IA | La respuesta real de la IA no sale en el simulador |
| R3 | `ai-chat-reads-heavier-than-a-messaging-app` | Yala IA con forma de chat de mensajería | Rediseño visible; el chat solo responde en el iPhone |
| R4 | `chat-draft-card-redesign` | La tarjeta de un registro en Yala IA: fila, píldoras, «Detalles» | Rediseño de hoy; se valida tocándola |
| R5 | `chat-dictation-looks-poor` | El panel de escucha del dictado: orbe, tiempo, Cancelar y Listo | El halo que sigue a tu voz no existe en el simulador |
| R6 | `record-selectors-open-at-medium-detent` | Cuenta, Subcategoría y Etiquetas abren a media altura | Es un gesto: se nota con el dedo |
| R7 | `voice-entry-end-to-end` | Registrar por voz desde el Panel, de punta a punta | Micrófono y transcripción reales |
| R8 | `image-entry-end-to-end-redesign` | Registrar por imagen: cámara, Fotos, PDF y sus fallos | Cámara, Fotos y el modelo de verdad no se prueban en el simulador |
| R9 | `settings-redesign-as-grouped-lists-like-ios` | Personalización como lista agrupada de iOS, en tus temas | Quitó el borde de las tarjetas: es identidad, y tú decides si se distinguen |
| R10 | `step-flows-should-match-the-sep15-reference` | Las guías de Apple Pay y Face ID paso a paso | Sale a la app Atajos y vuelve; eso solo pasa en un iPhone |
| R11 | `group-expense-views-redesign` | El gasto de grupo dice qué te toca y se edita con una frase | Rediseño de hoy; necesita grupos con más personas, que solo tienes en tu Yala de verdad |
| B1 | `session-exits-one-verb-per-session` | «Cerrar sesión» en privado espera a que suba lo tuyo antes de borrar | Riesgo de perder datos; la espera por iCloud no se simula |
| B2 | `restore-says-no-data-when-the-icloud-import-never-settled` | Con la red lenta, Restaurar dice «Seguimos trayendo tus datos» y no «No encontramos» | Sin esto, quien restaura con mala red cree que perdió todo |
| B3 | `restore-treats-budgets-and-groups-as-no-data` | Las tarjetas de «Encontramos tus datos», incluida la quinta sola en su fila | Es diseño y te toca decidir si se ve mal |
| B4 | `restore-start-fresh-keeps-the-imported-corpus` | «Empezar desde cero» en Restaurar enseña antes lo que hay en tu iCloud | Antes prometía empezar vacío y dejaba bajar lo viejo |
| B5 | `device-qa-apple-id-change-closes-private-session` | Apagar iCloud Drive NO saca el aviso de «Cambiaste de cuenta de iCloud» | Si sale, la app ofrece borrar datos a quien no cambió de cuenta |
| C1 | `groups-only-second-launch-mounts-icloud-mirror` | Una sesión solo de grupos no se trae tus finanzas de iCloud al reabrir | Privacidad: en el simulador no hay iCloud y el fallo no se ve |
| C2 | `groups-consent-door-spec` | El consentimiento de Grupos sale una vez y queda una fila en staging | Registro legal que nunca se vio en un teléfono (producción tenía 0 filas el 14-sep) |
| C3 | `full-mode-activation-must-ask-where-personal-data-lives` | «Activar Yala completo» pregunta dónde van tus datos y restaura sin duplicar los de grupo | Camino principal de solo-grupos a completo, decidido en el ADR |
| C4 | `welcome-private-fresh-start-skips-icloud-check` | «Es mi primera vez» → privado revisa tu iCloud y enseña cifras antes de nada | Es el primer lector de CloudKit del repo; si falla, todo usuario nuevo en privado se atasca |
| C5 | `groups-entry-on-a-mirrored-store-still-blocks-the-owner` | «Vengo por un grupo» tras restaurar ya no te bloquea, e iCloud sigue intacto | Es el callejón que encontraste tú el 9-sep |
| D1 | `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` | Un iPhone real ve la tarjeta «Tu cuenta en la nube» | Si falla, nadie puede crear una cuenta en la nube; solo un iPhone lo dice |
| D2 | `cloud-sign-in-discovers-account-kind` | Entrar con una cuenta solo-grupos no la convierte en completa; una cuenta que no existe ofrece crearla | Núcleo de identidad: a qué cuenta van tus datos |
| D3 | `previous-person-cloud-session-survives-fresh-start-and-reinstall` | Tras reinstalar, la app no entra sola con la cuenta anterior | Sale gratis en D2 |
| D4 | `snapshot-upload-has-no-ceiling-and-no-way-out` | «Cancelar la activación» aparece si la subida se para al 55 % | Muy alto: sin él, la migración se quedaba colgada para siempre |
| D5 | `forward-migration-steps-have-no-ceiling-and-no-exit` | «Activar la nube» termina de punta a punta tras cancelar una vez | Muy alto, y va en la misma pasada que D4 |
| D7 | `private-sign-out-proceeds-with-a-migration-in-flight` | Con la subida a la nube parada, «Cerrar sesión» no borra nada | Riesgo de perder datos; una subida en marcha no existe en el simulador |
| D6 | `reentry-counts-as-fresh-install` | Volver a tu cuenta de la nube tras reinstalar no parece una instalación nueva | Flujo que hará todo el que cambie de teléfono |
| E1 | `reverse-cutover-cerrado-para-cuentas-born-cloud` | «Volver a iCloud» con una cuenta nacida en la nube sube TODO a iCloud | Es la única pieza del repo marcada «NO medido» |
| F1 | `wipe-data-keeps-groups-but-drops-their-bridged-rows` | Tras «Vaciar datos», los gastos de tus grupos vuelven a tus cuentas, una sola vez | Toca dinero: sin el arreglo desaparecían de tus cuentas |

**Si hoy solo tienes hora y media:** el bloque R (son los cambios que van en el TestFlight 15 y los más
recientes) y el D (los dos «muy alto»). Lo que no hagas sigue en `qa` y no pasa nada. **El bloque F va siempre el
último**: «Vaciar datos» borra también el iCloud de Yala Dev que usan B y C.

## Antes de empezar (10 minutos, una vez)

1. **Actualiza `2.1` en el Mac**: en `~/Yala`, `git pull`.
2. **Instala Yala Dev en el iPhone.** Conéctalo por cable, abre `Yala.xcodeproj` en Xcode, arriba elige el
   scheme **Yala Dev** y tu iPhone como destino, y pulsa ▶. Tiene que ser Yala Dev compilada hoy desde `2.1`:
   el TestFlight que tienes no lleva lo de esta semana, y las cuentas G1-G3 viven en staging.
   - Yala Dev es **otra app** (otro icono) y va contra **staging**. Tu Yala de TestFlight y sus datos no se
     tocan.
   - Yala Dev usa **su propio iCloud** (`iCloud.com.jurgenschmidt.yala.dev`). Tus datos reales no cuentan
     como «datos en iCloud» para estas pruebas: los crea el bloque A.
   - **Yala Dev arranca en Free.** Para el bloque R enciende **Perfil → «Simular Pro»** (salvo donde el paso diga
     lo contrario).
3. **«Reinstalar» en este guion significa:** mantener pulsado el icono de Yala Dev → Eliminar app →
   Eliminar, y otra vez ▶ en Xcode. Borrar la app deja iCloud intacto.
4. **Ten a mano tres cuentas de Google de prueba** que no hayas usado nunca en staging. Aquí se llaman
   **G1** (acabará siendo solo de grupos), **G2** (tu cuenta de nube migrada) y **G3** (una cuenta que
   nace en la nube). Tu Apple ID, con iCloud y iCloud Drive encendidos.
5. **Network Link Conditioner**: en el iPhone, Ajustes → Desarrollador → Network Link Conditioner. Aparece
   tras instalar desde Xcode. Se usa en B2.
6. **Acceso al SQL Editor de Supabase, proyecto de staging**, para una consulta en C2.
7. **Para el bloque R:** dos o tres recibos de papel (o fotos de recibos en Fotos), un PDF de un recibo en
   Archivos, y otra app que suene (Música o Spotify).
8. **Para R11:** el **TestFlight 15** (versión 2.1), en tu iPhone, con tus grupos de verdad: un grupo
   de 3 o más personas y uno de 2, con algún gasto que pagó otra persona.

## Bloque A · Lo de todos los días (35 min, 10 de ellos esperando)

Deja además datos en el iCloud de Yala Dev para los bloques R, B y C.

1. **Paso 0, antes de nada: el usuario nuevo** (`restore-says-no-data…`, paso 3). Abre Yala Dev → «Empezar».
   - **A0 · El diseño nuevo.** Arriba a la izquierda, una píldora «‹ Volver»; el titular «¡Hola! ¿Qué quieres
     hacer en Yala?» con letra de serifa; las tres opciones en **una sola tarjeta** con líneas finas; sin logo.
   - Toca «Ya tengo una cuenta». **A0:** titular «¡Hola de nuevo!»; «Entrar con Apple» y «Entrar con Google» en
     blanco, una «o», y «Restaurar desde iCloud» solo con borde; debajo, «¿Es tu primera vez en Yala? Empieza
     aquí».
   - Toca «Restaurar desde iCloud», **sin** el Network Link Conditioner. Si el iCloud de Yala Dev está vacío,
     **PASA si** sale «No encontramos tus datos», y si «Empezar desde cero» pregunta antes de seguir.
   - **FALLA si** sale «Seguimos trayendo tus datos»: toda instalación nueva se quedaría esperando.
   - Si trae datos de pruebas viejas, anótalo y sigue: ese paso lo cubren los tests.
2. Vuelve atrás hasta «Ya tengo una cuenta» y toca **«Empieza aquí»**: **A0 PASA si** abre «Es mi primera vez».
   Elige «Tu cuenta en tu iCloud privado» y termina el onboarding, en soles.
3. **Crea los datos de prueba:** tres cuentas en soles, «QA Diario», «QA Divisa» y «QA Archivar», con 3-4
   movimientos cada una, una categoría tuya, una etiqueta y un presupuesto. Deja la app abierta un par de minutos
   con red para que suba a iCloud.
4. **A2 · El signo del chat.** Apunta el saldo de «QA Diario». En Yala IA, dicta «gasté 30 soles en el
   almuerzo», elige «QA Diario» en la píldora de la cuenta y toca **Guardar** en la tarjeta (no «Detalles»).
   - **PASA si** el saldo baja 30 y en Estadísticas los gastos del mes suben 30.
   - **FALLA si** el saldo sube.
5. **A3 · La divisa del chat.** Sin ninguna cuenta en dólares, dicta «gasté 50 dólares en un taxi» y elige
   «QA Diario».
   - **PASA si** el importe de la tarjeta pasa a `S/` **antes** de guardar, y tras guardar el saldo cuadra con
     la conversión.
   - **FALLA si** se guarda en dólares dentro de una cuenta en soles.
6. **A4 · Cambiar la divisa de una cuenta.** Hazlo sobre las cuentas de prueba: reescribe importes.
   Perfil (tu foto, arriba a la derecha) → Cuentas → «QA Divisa» → Divisa → USD → Guardar.
   - **PASA si** sale «¿Convertir N movimientos?» con el número real, y al aceptar los importes salen
     reexpresados, no el mismo número con otro símbolo.
   - Repite en «QA Diario» y toca **Cancelar**: la divisa vuelve a la de antes y nada cambia.
   - Crea una cuenta vacía y cámbiale la divisa: **cambia sin preguntar**.
7. **A5 · Archivar una cuenta.** Apunta el «Tienes S/ X en N cuentas» de «Tus finanzas» en el Panel. Perfil →
   Cuentas → «QA Archivar» → baja hasta **Acciones**: «Excluir de las estadísticas» está apagado.
   - Enciende **Archivar cuenta**. **PASA si** se enciende solo «Excluir de las estadísticas» y sale debajo un
     texto que dice que deja de sumar, que sus movimientos se ocultan en Registros y cómo volver a incluirla.
   - Apaga «Archivar» sin guardar: «Excluir» se apaga y el texto se va. Vuelve a encenderlo y guarda (✓).
   - **PASA si** en el Panel el total ya no la incluye y dice una cuenta menos.
   - Vuelve a ella (Perfil → Cuentas → **Archivadas**), apaga «Excluir» y guarda: el Panel la vuelve a sumar y a
     contar, y la cuenta sigue archivada.
8. **A1 · El aviso de pagos.** Ajustes → Notificaciones → «Pagos planificados» encendido, con la hora a
   **ahora + 10 min**.
   - Crea 2 pagos con fecha de hoy y 1 con fecha de mañana. **Los tres con recurrencia «Una sola vez»**: si
     no, el editor los fecha el día 1 del mes que viene y la prueba sale verde por la razón equivocada.
   - Cierra Yala Dev deslizando hacia arriba y bloquea el iPhone. Espera.
   - **PASA si** a la hora llega **un solo** aviso, «Tienes 2 pagos planificados para hoy 📅»; tocarlo abre
     los pagos planificados, y al abrir la app no llega otra tanda por los mismos pagos.
   - **FALLA si** no llega nada, llegan dos, o el número está mal.

## Bloque R · Los rediseños de esta semana (60 min)

Son cambios que se ven, y por eso se juzgan a mano: si algo **se ve mal** aunque funcione, dilo igual. Van en
Yala Dev desde `2.1`, con la sesión privada y los datos del bloque A, y **«Simular Pro» encendido** (Perfil).
R11 es la excepción: va en el TestFlight, al final del bloque.

1. **R1 · La cabecera del Panel, en todas partes.** En el **Panel**, mira el hero: «Disponible» arriba a la
   izquierda, la píldora del período a la derecha, la cifra grande debajo.
   - Ve a **Estadísticas**. En **Resumen**, **Tendencias**, **Registros** y **Distribución** (desliza los chips),
     **PASA si** la cabecera se lee igual: rótulo arriba a la izquierda, píldora a la derecha, cifra debajo. En
     Distribución el rótulo dice «Saldo de cuentas», y no se mueve al deslizar el carrusel a Subcategorías o
     Etiquetas, ni al pasar a Detalle y volver.
   - En las cuatro, abajo a la derecha, **Yala IA** y **«+»**; «+» abre Nuevo registro (ciérralo sin guardar). Baja
     hasta el final: la última tarjeta queda **por encima** de los dos botones.
   - Gira el iPhone en Resumen: la cabecera pasa a la banda compacta (cifra a la izquierda, período y
     entradas/salidas a la derecha). Vuelve a vertical.
   - **Planificación → Pagos planificados**: «Total del mes · Este mes» arriba a la izquierda y la cifra debajo.
   - **FALLA si** en algún sitio la cabecera sale centrada, falta el rótulo o faltan los dos botones.
2. **R2 · El resumen de Tendencias.** Estadísticas → **Tendencias** con «Este mes». Baja hasta el final.
   - **PASA si** sale una tarjeta con 2-4 frases con viñeta, una por gráfica.
   - Cambia a **«Todo el tiempo»**: desaparece la frase de la comparativa.
   - Toca **«Generar análisis IA»**: sale el cargando y luego 2-4 frases con icono que citan cifras de las
     gráficas. **«Regenerar»** trae otro texto. Cambia el período: vuelven las frases sin IA con el botón.
   - Modo avión y «Generar análisis IA»: siguen las frases sin IA con «Algo salió mal. Intenta de nuevo.» debajo.
     Quita el modo avión.
   - Con los pocos meses que tiene Yala Dev, la frase de «Tu gasto viene subiendo desde hace N meses» **no**
     saldrá: es lo esperado.
3. **R3 · Yala IA como un chat.** Toca «Pregúntale a Yala» (Panel o Registros).
   - **PASA si** arriba van la fecha y dos avisos en gris pequeño, y debajo **una** burbuja blanca con el saludo
     y tres preguntas separadas por líneas finas. Tocar una la envía como si la hubieras escrito.
   - En la respuesta, los párrafos salen separados y las cifras clave en negrita.
   - En la caja: el «+» va fuera, a la izquierda, y abre Temas. Vacía, se ve el micro; escribe una letra y el
     micro pasa a enviar; bórrala y vuelve el micro. Debajo de la caja no queda texto gris.
4. **R4 · La tarjeta de un registro.** Escribe «Gasté 45 en un taxi y 120 en el súper».
   - **PASA si** cada registro sale como una fila (icono, nota, importe `S/ 45.00`) con píldoras debajo, y
     «Gasto» no va en rojo.
   - Si alguno sale sin subcategoría: su «Guardar» **se ve** apagado y hay una píldora ámbar. Tócala, elige una:
     la píldora se va y «Guardar» se enciende.
   - La píldora de la cuenta abre el selector de cuentas; la fecha, el calendario de Nuevo registro.
   - **«Detalles»** abre una hoja a media altura **con el chat detrás**. Cambia la nota y la fecha; «Listo»
     cierra y la tarjeta lo refleja. Desde «Detalles», «Abrir en el formulario completo» cierra el chat y abre
     Nuevo registro relleno; ciérralo sin guardar.
   - Vuelve al chat y pulsa «Guardar» en una tarjeta: queda la misma fila con «✓ Registrado».
5. **R5 · El dictado.** En Yala IA, toca el micro.
   - **PASA si** la caja se cambia por un panel con «Escuchando…», la pista, el orbe, el tiempo corriendo y
     Cancelar y Listo.
   - Habla en voz normal y luego más fuerte: **el halo del orbe crece con la voz y se encoge en silencio**. Es lo
     que el simulador no puede medir.
   - Pon música en otra app, vuelve y toca **Cancelar**: vuelve la caja vacía, sin aviso de error, y la música
     vuelve a sonar normal.
   - Micro otra vez, di «gasté 25 en el almuerzo con la tarjeta» y **Listo**: el orbe gira, se lee «Revisa tu
     texto antes de enviarlo.» y «0:0X grabados». **PASA si** el texto queda en la caja **sin enviarse**.
6. **R6 · Las hojas a media altura.** Panel → «+» (Nuevo registro).
   - Toca **Cuenta**: **PASA si** abre a media altura, con el formulario detrás. Arrástrala hacia arriba: pasa a
     pantalla completa. Elige una cuenta: se cierra y el chip la muestra.
   - **Subcategoría**: media altura; al deslizar la rejilla hacia arriba, la hoja crece y luego desplaza.
   - **Etiquetas**: media altura. Marca una y **Guardar**.
   - Cambia a **Transferencia**: las cuentas de origen y destino, las dos a media altura. Cierra sin guardar.
   - En Yala IA, en una tarjeta, la píldora de subcategoría o de cuenta: media altura. Y «Detalles» → Cuenta,
     también.
7. **R7 · Registrar por voz.** En el Panel, toca el icono de onda (o «+» → Voz). La primera vez iOS pide el
   micrófono.
   - **PASA si** la hoja sube a media altura y **ya escucha**: «Escuchando…», el orbe con el color de tu tema, el
     tiempo con un punto rojo, Cancelar y Listo.
   - **Cancelar** cierra sin aviso, y la música de otra app vuelve a sonar.
   - Otra vez: di «almuerzo 25 con la tarjeta» y **Listo**. Sale «Esto entendí» con una fila (Almuerzo, su
     subcategoría y el importe) y píldoras. Lo que falte va en ámbar con Guardar apagado; complétalo.
     **Guardar**: la fila pasa a «Registrado». Ciérrala: el registro está en Registros.
   - Di dos gastos («taxi 12 y café 8»): dos filas y «Guardar 2» registra los dos.
   - Graba otra vez y toca **Volver a grabar**: escucha de nuevo, y en la Bandeja no queda el borrador anterior.
   - Graba y cierra con la X sin guardar: el borrador está en la Bandeja.
   - Con modo avión, toca Voz: «Sin conexión», con «Usar imagen» y «Volver a grabar». Quita el modo avión.
8. **R8 · Registrar por imagen.** Panel → botón de imagen.
   - **PASA si** sale una hoja a media altura con **Cámara · Fotos · Archivo**.
   - **Cámara** (la primera vez, el aviso de permiso con el texto de Yala; acepta). Fotografía un recibo:
     «Leyendo tu foto…» con la foto y una línea moviéndose, y luego «Esto leí» con comercio, importe y categoría.
     **Guardar**: la fila pasa a «Registrado» y el disponible del Panel baja ese importe.
   - **Fotos** → elige tres recibos: «Foto 1 de 3…», una fila por registro y «Guardar 3».
   - **Archivo** → el PDF del recibo: lo lee como una foto.
   - Modo avión → elige una foto: «Sin conexión» con Reintentar. Quita el modo avión → Reintentar: lo lee.
   - Ajustes de iOS → Yala Dev → Cámara apagada. Vuelve y toca Cámara: «Yala no puede usar la cámara» con «Abrir
     Configuración». Vuelve a encender la cámara.
   - **Apaga «Simular Pro».** En Fotos, comparte un recibo a Yala Dev: **PASA si** sale el aviso de Pro, no la
     lectura. Vuelve a encender «Simular Pro».
9. **R9 · Personalización.** Perfil → **Personalización**.
   - **PASA si** los ajustes van en bloques blancos (de tarjeta en tema oscuro) sobre el fondo de siempre, con una
     línea fina entre filas y la cabecera de cada sección en gris pequeño. Al final están los 13 ajustes (14 si
     tienes un idioma de la app forzado).
   - Perfil → **Temas**: pasa a uno oscuro y a uno traslúcido, y vuelve a Personalización. **Tu veredicto:** ¿los
     bloques se distinguen del fondo **sin el borde fino** que tenían? Si en alguno no, dilo: es lo único de
     identidad que cambió.
   - «Idioma de voz»: el valor sale en gris (no en morado) y el menú cambia el idioma.
   - Abre **Divisa y Cambio**, **Vaciar datos** (**no confirmes**), **Privacidad y datos IA**, **Tutoriales** y
     «Personalizar resumen de IA»: todo hace lo de antes.
10. **R10 · Las guías paso a paso.** Perfil → **Ayuda** → **Tutoriales** → **Registrar con Apple Pay**.
    - **PASA si** arriba dice «Paso 1 de 4» con la primera barra llena, y bajo el título «Pagos de Apple Pay en tu
      bandeja: N».
    - **Abrir Atajos**: se abre la app Atajos. Vuelve a Yala Dev: **PASA si** está en «Paso 2 de 4», con el paso 1
      marcado ✓.
    - **Hecho** dos veces hasta «Paso 4 de 4»; el vídeo se reproduce al tocarlo. **Me atasqué** abre el formulario
      de soporte (ciérralo). **Listo**: vuelves a Tutoriales con ✓ en «Registrar con Apple Pay».
    - En Yala Dev, Ajustes → Seguridad → **Protege Yala con Face ID**: «Hecho» avanza los 3 pasos, y en «Lo que vas a ver» sale
      el icono de Yala que tienes puesto.
11. **Texto al máximo, una pasada.** Ajustes de iOS → Accesibilidad → Pantalla y tamaño del texto → Texto más
    grande, con «Tamaños más grandes» al máximo. Repasa rápido:
    - las tres preguntas de Yala IA se parten en líneas sin cortarse (R3);
    - el panel del dictado no se corta y sus dos botones se leen enteros (R5);
    - en Nuevo registro, **Cuenta abre grande**, no a media altura (R6);
    - la hoja de Voz abre grande y nada se corta (R7);
    - las frases de Tendencias no se cortan (R2).
    - Con **Reducir movimiento** (Accesibilidad → Movimiento): el halo del dictado y de Voz no se mueve y al
      procesar sale el spinner del sistema (R5, R7).
    - Devuelve el texto y el movimiento a como los tenías.
12. **R11 · El gasto de grupo (en el TestFlight, no en Yala Dev).** Yala Dev no tiene grupos con más personas, y
    montarlos pide una cuenta y un teléfono por persona. Por eso va en el **TestFlight 15** (versión
    2.1, abre TestFlight → Yala → Instalar), con tus grupos de verdad. **Lo que guardes ahí lo ven los demás del grupo**: si no quieres tocar un
    gasto real, apunta uno de prueba de S/ 1 y bórralo al terminar.
    - Grupos → un grupo de 3 → toca un gasto con partes iguales que pagó otra persona. **PASA si** dice «Tu parte ·
      Le debes a <nombre>» y la lista de las tres personas con lo que pone cada una, **sin barra**.
    - **Editar**: grupo y fecha en una línea pequeña; debajo del monto, «Pagado por <nombre> y dividido en partes
      iguales», con las dos piezas en el color de tu tema (no turquesa).
    - Toca la pieza del reparto: se abre ahí mismo, sin hoja aparte, con la barra. Cambia a **Porcentaje** con
      montos distintos; toca la pieza del pagador: el reparto se pliega y salen los avatares. Elige a otra persona
      y **Guardar** (en tu gasto de prueba). Ábrelo otra vez: ahora sí sale la barra.
    - En un grupo de 2: una pastilla con la frase entera. Tócala, elige «Pagó <otra> · es todo tuyo» y mira cómo
      cambia la frase. Otra vez → **Más opciones**: se abre el reparto completo. Cierra sin guardar si es real.
    - En un gasto que pagaste tú, sin cuenta enlazada: «Cuenta · Selecciona una cuenta» con aviso y Guardar
      apagado; al elegir cuenta, Guardar se enciende.
    - **Nuevo gasto** en el grupo → **Subcategoría** (y **Cuenta** si aparece): abren a media altura (es el último
      paso de R6).
    - Con el texto grande y en modo claro, repite las dos primeras: la frase pasa a dos líneas si no cabe.

## Bloque B · Salir y restaurar en privado (40 min)

Parte del estado del bloque A: sesión privada con datos, ya subidos a iCloud.

1. **B1 · Cerrar sesión sin red, y matar la app a mitad.** Modo avión. Crea un gasto. Ajustes → «Cerrar
   sesión» → confirma. En cuanto salga «Guardando tus cambios…», **mata la app**.
   - **PASA si** al reabrir la sesión y los datos siguen ahí, gasto incluido.
2. **B1 · Cerrar sesión sin red, esperando.** Aún en modo avión, «Cerrar sesión» otra vez.
   - **PASA si** sale «Guardando tus cambios…» y a los 45 s un aviso que dice **1 cambio sin subir**.
   - Toca «Esperar» y quita el modo avión: **tiene que terminar solo** y llevarte al Welcome.
3. **B2 · Restaurar con la red lenta.** Network Link Conditioner en «Very Bad Network». Reinstala →
   «Ya tengo una cuenta» → «Restaurar desde iCloud». Espera más de 90 s.
   - **PASA si** sale «Seguimos trayendo tus datos» y **no** «No encontramos tus datos».
   - «Reintentar búsqueda» vuelve a la barra con los conteos subiendo.
   - Apaga el condicionador y reintenta: termina en la pantalla con las cifras.
   - Con tan pocos datos puede que el import acabe antes de 90 s. No es un fallo: anótalo y el ticket se
     cierra con los tests.
4. **B3 · Las tarjetas.** En «Encontramos tus datos» mira las tarjetas: movimientos, cuentas, categorías
   (icono de etiqueta) y presupuestos (gráfico circular). Con cinco cifras, la quinta queda sola en su
   fila. **Tu veredicto: ¿se ve mal?** Si sí, es un ticket nuevo de diseño, no un FAIL.
5. **B4 · «Empezar desde cero» enseña antes qué hay.** En esa misma pantalla, «Empezar desde cero» →
   confirma.
   - **PASA si** sale «Revisando qué hay en tu iCloud…» y luego un aviso con cifras que casan con lo que
     creaste, con tres salidas: «Traer mis datos», «Empezar de cero» y la flecha de volver.
   - **FALLA si** te lleva directo al onboarding, o si dice que no hay nada.
   - Toca **«Traer mis datos»** (no borres) y termina de restaurar. Cierra y reabre la app dos veces: los
     datos siguen ahí.
6. **B5 · iCloud Drive apagado no es un cambio de cuenta.** Ajustes de iOS → tu nombre → iCloud → apaga
   **iCloud Drive**, sin cerrar sesión. Abre Yala Dev.
   - **PASA si** NO sale ningún aviso de «Cambiaste de cuenta de iCloud».
   - **Si sale, para y avísame**: la app estaría ofreciendo borrar datos a quien no cambió de cuenta.
   - Vuelve a encender iCloud Drive.
7. **B1 · Cerrar sesión con red.** Crea un gasto, espera 10 s, «Cerrar sesión».
   - **PASA si** cierra sin aviso y vuelve al Welcome.
   - **A0 con texto grande (opcional, 1 min):** ya en el Welcome, sube el texto al máximo y toca «Empezar». El
     titular no queda debajo de la píldora «‹ Volver» y la pantalla hace scroll. Devuelve el texto a su tamaño.

## Bloque C · Solo grupos, sin traerse tu iCloud (50 min)

Parte de un iCloud de Yala Dev con datos, que es lo que dejó el bloque B.

1. **C1 y C2 · Entrar por grupos.** Reinstala → «Vengo por un grupo» → «Crear mi primer grupo».
   - **PASA si** el orden es: pantalla que explica Grupos → entrar con Google (**G1**) → «Grupos en la nube»
     → «¿Cómo te llamas?».
   - Acepta, pon tu nombre, crea el grupo y apunta un gasto del grupo pagado por ti.
2. **C1 · Reabrir no trae nada.** Mata la app del todo y ábrela; repítelo tres veces.
   - **PASA si** solo ves la pestaña Grupos con tu grupo: ninguna cuenta, movimiento ni presupuesto del
     bloque A.
3. **C2 · El registro del consentimiento.** En el SQL Editor de staging:
   `select user_id, text_version, path, accepted_at from public.groups_consents order by accepted_at desc limit 5;`
   - **PASA si** hay **una** fila nueva tuya con `text_version = 1` y `path = organizer`. Apunta su
     `accepted_at`.
4. **C1 · Cerrar la sesión de grupos.** Más → tu cuenta → «Cerrar sesión». Mata la app y reábrela.
   - **PASA si** no aparece nada del histórico de iCloud.
5. **C2 · El consentimiento no se repite.** «Vengo por un grupo» y entra otra vez con **G1**.
   - **PASA si** NO vuelve a salir «Grupos en la nube».
   - Repite el SQL: sigue habiendo una sola fila, con el mismo `accepted_at`.
6. **C3 · Activar Yala completo, restaurando.** Perfil → «Activar Yala completo».
   - **PASA si** sale «¿Dónde guardamos tus finanzas?» con dos tarjetas.
   - Elige privado: aviso con las cifras de tu iCloud → «Traer mis datos» → reabre cuando lo pida →
     termina la restauración.
   - **PASA si** vuelven tus datos del bloque A con tu nombre y tu divisa de antes (no los de Grupos), y el
     gasto del grupo aparece **una sola vez** en Registros.
7. **C4 y C5 · Primera vez en privado, y después un grupo.** Reinstala → «Es mi primera vez» → «Tu cuenta
   en tu iCloud privado».
   - **C4 PASA si** sale «Revisando qué hay en tu iCloud…» y luego el aviso con cifras que casan, con tres
     salidas, **antes** de cualquier pantalla de «reabre Yala».
   - **C4 FALLA, y es bloqueante, si** sale siempre «No pudimos conectarnos a iCloud».
   - Toca la flecha: vuelves a la elección privado/nube. Entra otra vez por privado: **las mismas cifras**.
   - Ahora «Traer mis datos», deja que baje y mata la app. Ábrela, vuelve atrás hasta el Welcome →
     «Vengo por un grupo» → «Crear mi primer grupo».
   - **C5 PASA si** no sale ninguna pantalla que te bloquee por tener datos guardados. Sale «Estamos
     subiendo tus últimos cambios…» y luego la de reabrir.
   - Ve a la pantalla de inicio, espera dos segundos y ábrela: **aterrizas en la puerta de Grupos** y
     sigues al inicio de sesión sin volver a elegir. El Panel está vacío.
8. **C5 y C1 · iCloud sigue intacto.** Reinstala → «Ya tengo una cuenta» → «Restaurar desde iCloud».
   - **PASA si** vuelve **todo** el histórico del bloque A, sin pedirte reabrir en bucle.
   - **Si vuelve vacío, es el fallo grave**: para y avísame.

## Bloque D · La nube (45 min)

Necesita **G1**, que tras el bloque C ya es una cuenta solo de grupos.

1. **D1 · La tarjeta de la nube.** Reinstala, abre con red y espera 10 s. «Empezar» → «Es mi primera vez».
   Si sale «Entra a tu cuenta», toca «Crear otra cuenta».
   - **PASA si** sale «Elige dónde quieres guardar tus datos» con las dos tarjetas: «Tu cuenta en la nube»
     y «Tu cuenta en tu iCloud privado».
   - **FALLA si** sale otra pantalla dos veces seguidas.
2. **D3 · La cuenta anterior no entra sola.** Vuelve atrás → «Ya tengo una cuenta».
   - **PASA si** pide elegir entre Apple y Google, y **no** entra solo con G1.
3. **D2 · Una cuenta solo de grupos no se vuelve completa.** Entra con Google **G1**.
   - **PASA si** aterrizas en la puerta de Grupos, **no** en el Panel.
4. **D4 y D5 · Activar la nube, y cancelar al 55 %.** Reinstala → «Es mi primera vez» → «Tu cuenta en tu
   iCloud privado» → termina el onboarding. Mete **unos cientos de movimientos**: Ajustes → Importar, con
   un CSV exportado desde tu Yala de verdad. Si no puedes exportar, crea 20-30 a mano: la barra irá más
   rápido.
   - Ajustes → «Dónde viven tus datos» → «Migrar a la nube» → «Activar la nube» → consentimiento → entra con
     Google **G2**.
   - **Control:** mientras sube con red, el botón de cancelar sale deshabilitado.
   - **Al llegar al 55 %, pon el modo avión.**
   - **PASA si**, cuando el intento se detiene, aparece «Cancelar la activación» debajo de «Retomar».
   - **D7 · Cerrar sesión no borra nada a mitad.** Antes de cancelar, vuelve a Perfil → «Cerrar sesión» →
     confirma. **PASA si** sale «No pudimos cerrar tu sesión» diciendo que el paso de tus datos entre iCloud y la
     nube todavía no terminó, y al tocar OK sigues en la app con tus movimientos. **FALLA si** sale «Cierra y vuelve
     a abrir Yala» o la espera de iCloud. Vuelve a «Dónde viven tus datos» y sigue con el cancelar.
   - «Seguir activando la nube» no cambia nada.
   - «Sí, cancelar» te devuelve a «Migrar a la nube» **sin alerta ni tarjeta de fallo**.
5. **D5 · Ahora de punta a punta.** Quita el modo avión y «Activar la nube» otra vez con **G2**.
   - **PASA si** la barra pasa por 22, 35, 55, 75 y 80 % sin pararse y acaba en «cierra y vuelve a abrir
     Yala».
   - Al reabrir, Ajustes → «Dónde viven tus datos» dice que están en la nube.
6. **D6 · Volver a tu cuenta tras reinstalar.** Reinstala → «Ya tengo una cuenta» → Google **G2**.
   - **PASA si** ves «Descargando tus datos…» mientras la app está vacía, y acabas en «¡Tu cuenta está
     lista!».
   - Su botón te lleva a la app: sin onboarding y sin «reinicia Yala».
   - No aparecen «Primeros pasos» ni la oferta de prueba.
   - Las cuentas y las categorías no salen duplicadas.

## Bloque E · Volver a iCloud desde una cuenta nacida en la nube (50 min, el más caro)

1. **D2 · Una cuenta que no existe.** Reinstala → «Ya tengo una cuenta» → Google **G3**.
   - **PASA si** sale «No encontramos una cuenta» **con un botón**.
   - El botón abre el consentimiento con Google y el alta crea la cuenta. Es tu cuenta nacida en la nube.
2. **E1 · Preparar.** Crea 15-20 movimientos en 2-3 cuentas, una categoría, un presupuesto y un pago
   recurrente.
   - Ajustes → CloudSync Debug tiene que decir `eligible ✅ · born-cloud`. Si no lo dice, repite el alta
     por «Es mi primera vez» → «Tu cuenta en la nube» con otra cuenta.
   - Borra 2-3 movimientos y una cuenta, y **apunta cuáles**.
3. **E1 · Volver.** Ajustes → «Dónde viven tus datos» → «Volver a iCloud» → las dos confirmaciones →
   reabre cuando lo pida. Cronometra la fase «Volviendo a iCloud…».
   - **PASA si** acabas en modo privado con **todo** el histórico, y lo que borraste **sigue borrado**.
   - En CloudSync Debug, el contador de filas con `ckRecordName` pasa de 0 a por lo menos las filas vivas.
   - Si tienes a mano la CloudKit Console, en la base privada del contenedor `.dev` aparecen los registros.
   - **Si se queda clavado al 95 %**: sal por «Cancelar y seguir en la nube», y apunta cuántas filas tenías
     y cuánto tardó.

## Bloque F · «Vaciar datos» con grupos (15 min, siempre el último)

«Vaciar datos» borra tus datos de este iPhone **y** del iCloud de Yala Dev, así que va después de todo lo
demás. Parte de una sesión privada, la que dejó E u otra cualquiera de Yala Dev.

1. **Monta el grupo.** Pestaña Grupos: si no estás dentro, entra con Google **G1**. Abre el grupo del
   bloque C (o crea uno) y apunta un gasto «QA Vaciar» de 20, pagado por ti.
2. **Apunta lo que hay.** Abre Registros y anota los gastos de grupo que ves; «QA Vaciar» tiene que estar.
   Si el Inbox te pregunta de qué cuenta salió, contesta. Mira también el saldo del grupo en Grupos.
3. **Vacía.** Perfil → «Vaciar datos» (debajo de «Dónde viven tus datos»; dice «Borra tus datos. Tu cuenta
   y tus grupos se conservan») → confirma → «Vaciar definitivamente».
   - Tiene que llevarte directo al onboarding personal, no a la bienvenida. Termínalo y crea una cuenta.
4. **Reabre.** Cierra Yala Dev del todo (desliza hacia arriba en el selector de apps) y ábrela.
   - **PASA si** en Registros vuelven los gastos de grupo del paso 2, **una sola vez cada uno**; el Inbox
     tiene un borrador por cada gasto que pagaste, preguntando la cuenta; y en Grupos el saldo sigue igual.
   - **FALLA si** tras dos arranques en frío no han vuelto, o si alguno sale dos veces.
5. **Otra vez.** Cierra y abre Yala Dev de nuevo: nada se duplica.
   - Si en el grupo tienes a otra persona que te pagó una liquidación, mírala también: vuelve a la cuenta
     de grupos una vez y el Inbox pregunta a qué cuenta llegó. Sin esa persona, no hace falta.

## Al terminar cada ticket

- **No inventes un PASS.** Si no se pudo comprobar, se dice qué faltó y se queda en `qa/`.
- **PASS** → `tickets/done/` con `qa-status: passed`, `qa-date`, una sección «QA Visual» y la evidencia.
  **FAIL** → `tickets/in-progress/` con `qa-status: failed` y lo que viste.
- Basta con que me pases el número del paso y PASA/FALLA («R4 pasa, B2 falla: salió X»). En el bloque R vale
  también «se ve mal: …» aunque funcione. El board lo muevo yo.
- `previous-person-cloud-session-survives-fresh-start-and-reinstall`: su paso 4 es instalar un TestFlight
  **encima** del anterior, sin borrar, y comprobar que la sesión de la nube sigue abierta. Se hace con el
  **TestFlight 15** encima del 14: antes de pulsar «Actualizar», deja abierta una sesión de la nube en
  el 14 que tienes. Si no tienes ninguna, ese paso se queda en `qa` y no frena nada.
- Actualiza `docs/TICKETS.md` (la fila y el conteo) y este guion. El índice se comprueba con un diff
  contra el disco, no a ojo.
