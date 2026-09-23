# Guion de la tanda de QA

> **Qué es esto.** La cola de `tickets/qa/` y el guion para recorrerla en el iPhone, agrupada **por
> montaje** y no por ticket: una reinstalación sirve a tres tickets si se hacen seguidos.
>
> **Actualizado: 2026-09-23 · 21 tickets.** Sale del barrido del 2026-09-23 (encargo
> `2026-09-23-barrido-qa-in-qa-pre-device`). De 80 tickets en `qa`, **59 bajaron a `done` sin device-QA**:
> casos raros, montajes de dos teléfonos o de servidor, o ya cubiertos por tests. Cada uno lleva al final
> su sección «Barrido de `qa` · 2026-09-23» con el porqué. **Los 21 de aquí son los que merece la pena
> probar a mano**, y cada uno dice en esa misma sección qué recorridos bastan para cerrarlo.
>
> Al mover algo a `qa/` o sacarlo de ahí, actualiza este guion.
>
> `qa` NO significa «terminado»: significa que el código está hecho y verificado hasta donde el simulador
> alcanza.

## La lista corta

En el orden del guion. Una línea por ticket: qué pruebas y por qué no basta con los tests.

| # | Ticket | Qué pruebas | Por qué a mano |
|---|---|---|---|
| A1 | `scheduled-payments-notif-dedup` | El resumen de pagos del día llega a su hora con la app cerrada, una sola vez | Lo reportaste tú en el iPhone, y las notificaciones reales no salen en el simulador |
| A2 | `chat-draft-drops-the-expense-sign` | Un gasto dictado al chat baja el saldo, no lo sube | Toca saldos de uso diario; el chat necesita App Attest y solo responde en el iPhone |
| A3 | `chat-draft-stamps-its-own-currency-not-the-account` | «50 dólares» sobre una cuenta en soles se guarda en soles | Mismo dictado que A2, un minuto más |
| A4 | `changing-an-account-currency-orphans-its-whole-history` | Cambiar la divisa de una cuenta pregunta y convierte todo su histórico | Es lo único de la app que reescribe importes ya guardados; el selector no responde a la automatización |
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
| D6 | `reentry-counts-as-fresh-install` | Volver a tu cuenta de la nube tras reinstalar no parece una instalación nueva | Flujo que hará todo el que cambie de teléfono |
| E1 | `reverse-cutover-cerrado-para-cuentas-born-cloud` | «Volver a iCloud» con una cuenta nacida en la nube sube TODO a iCloud | Es la única pieza del repo marcada «NO medido» |

**Si hoy solo tienes hora y media:** el bloque D (los dos «muy alto») y el B. Lo que no hagas sigue en
`qa` y no pasa nada.

## Antes de empezar (10 minutos, una vez)

1. **Actualiza `2.1` en el Mac**: en `~/Yala`, `git pull`.
2. **Instala Yala Dev en el iPhone.** Conéctalo por cable, abre `Yala.xcodeproj` en Xcode, arriba elige el
   scheme **Yala Dev** y tu iPhone como destino, y pulsa ▶. Tiene que ser Yala Dev compilada hoy: el
   TestFlight 13 es del 9-sep y no lleva casi nada de esta lista.
   - Yala Dev es **otra app** (otro icono) y va contra **staging**. Tu Yala de TestFlight y sus datos no se
     tocan.
   - Yala Dev usa **su propio iCloud** (`iCloud.com.jurgenschmidt.yala.dev`). Tus datos reales no cuentan
     como «datos en iCloud» para estas pruebas: los crea el bloque A.
3. **«Reinstalar» en este guion significa:** mantener pulsado el icono de Yala Dev → Eliminar app →
   Eliminar, y otra vez ▶ en Xcode. Borrar la app deja iCloud intacto.
4. **Ten a mano tres cuentas de Google de prueba** que no hayas usado nunca en staging. Aquí se llaman
   **G1** (acabará siendo solo de grupos), **G2** (tu cuenta de nube migrada) y **G3** (una cuenta que
   nace en la nube). Tu Apple ID, con iCloud y iCloud Drive encendidos.
5. **Network Link Conditioner**: en el iPhone, Ajustes → Desarrollador → Network Link Conditioner. Aparece
   tras instalar desde Xcode. Se usa en B2.
6. **Acceso al SQL Editor de Supabase, proyecto de staging**, para una consulta en C2.

## Bloque A · Lo de todos los días (30 min, 10 de ellos esperando)

Deja además datos en el iCloud de Yala Dev para los bloques B y C.

1. **Paso 0, antes de nada: el usuario nuevo** (`restore-says-no-data…`, paso 3). Abre Yala Dev →
   «Ya tengo una cuenta» → «Restaurar desde iCloud», **sin** el Network Link Conditioner.
   - Si el iCloud de Yala Dev está vacío, **PASA si** sale «No encontramos tus datos», y si «Empezar desde
     cero» pregunta antes de seguir.
   - **FALLA si** sale «Seguimos trayendo tus datos»: toda instalación nueva se quedaría esperando.
   - Si trae datos de pruebas viejas, anótalo y sigue: ese paso lo cubren los tests.
2. Vuelve atrás → «Es mi primera vez» → «Tu cuenta en tu iCloud privado» → termina el onboarding, en soles.
3. **Crea los datos de prueba:** dos cuentas en soles, «QA Diario» y «QA Divisa», con 3-4 movimientos cada
   una, una categoría tuya y un presupuesto. Deja la app abierta un par de minutos con red para que suba a
   iCloud.
4. **A2 · El signo del chat.** Apunta el saldo de «QA Diario». En el chat, dicta «gasté 30 soles en el
   almuerzo», elige «QA Diario» y toca **Guardar en la tarjeta** (no «Editar»).
   - **PASA si** el saldo baja 30 y en Estadísticas los gastos del mes suben 30.
   - **FALLA si** el saldo sube.
5. **A3 · La divisa del chat.** Sin ninguna cuenta en dólares, dicta «gasté 50 dólares en un taxi» y elige
   «QA Diario».
   - **PASA si** la etiqueta del importe pasa a PEN en la tarjeta **antes** de guardar, y tras guardar el
     saldo cuadra con la conversión.
   - **FALLA si** se guarda en USD dentro de una cuenta en soles.
6. **A4 · Cambiar la divisa de una cuenta.** Hazlo sobre las cuentas de prueba: reescribe importes.
   Ajustes → Cuentas → «QA Divisa» → Divisa → USD → Guardar.
   - **PASA si** sale «¿Convertir N movimientos?» con el número real, y al aceptar los importes salen
     reexpresados, no el mismo número con otro símbolo.
   - Repite en «QA Diario» y toca **Cancelar**: la divisa vuelve a la de antes y nada cambia.
   - Crea una cuenta vacía y cámbiale la divisa: **cambia sin preguntar**.
7. **A1 · El aviso de pagos.** Ajustes → Notificaciones → «Pagos planificados» encendido, con la hora a
   **ahora + 10 min**.
   - Crea 2 pagos con fecha de hoy y 1 con fecha de mañana. **Los tres con recurrencia «Una sola vez»**: si
     no, el editor los fecha el día 1 del mes que viene y la prueba sale verde por la razón equivocada.
   - Cierra Yala Dev deslizando hacia arriba y bloquea el iPhone. Espera.
   - **PASA si** a la hora llega **un solo** aviso, «Tienes 2 pagos planificados para hoy 📅»; tocarlo abre
     los pagos planificados, y al abrir la app no llega otra tanda por los mismos pagos.
   - **FALLA si** no llega nada, llegan dos, o el número está mal.

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

## Al terminar cada ticket

- **No inventes un PASS.** Si no se pudo comprobar, se dice qué faltó y se queda en `qa/`.
- **PASS** → `tickets/done/` con `qa-status: passed`, `qa-date`, una sección «QA Visual» y la evidencia.
  **FAIL** → `tickets/in-progress/` con `qa-status: failed` y lo que viste.
- Basta con que me pases el número del paso y PASA/FALLA («B2 pasa, C5 falla: salió X»). El board lo
  muevo yo.
- `previous-person-cloud-session-survives-fresh-start-and-reinstall` **no se cierra hoy**: le falta el
  paso 4, que es instalar el próximo TestFlight **encima** del 13 sin borrar y comprobar que la sesión de
  la nube sigue abierta.
- Actualiza `docs/TICKETS.md` (la fila y el conteo) y este guion. El índice se comprueba con un diff
  contra el disco, no a ojo.
