# Tanda de QA · 2.2 · lote decidido 14 — Grupos: invitar, la web de invitación, unirse, aprobar y avisos

Barrido del 2026-10-21, acotado a las 11 cards de la sesión. **Revisadas 11 · cerradas en el barrido 4 · para el
iPhone 7 · para capturas 0** (el antes y el después ya están en
`~/Claude/entregas/Yala--lote-decidido-2-2-14-grupos-invitar-y-unirse/capturas/`). Tiempo total: **~25 min**, con el
iPhone y el iPad a la vez.

Lo que se queda necesita **inicio de sesión real**, **dos dispositivos con dos cuentas**, **notificaciones push** o
**la web publicada** (§4). En el simulador se probó todo lo demás: la tarjeta del grupo antes de la cuenta, «Ya estás en
«X»», los avisos, la pestaña «en camino», las solicitudes y la pregunta de cuentas pendientes.

## Bloqueantes

| Card | ¿Bloquea 2.2? | Por qué |
|---|---|---|
| L12-17 | Sí | Cambia el orden del primer contacto de un invitado: si la cadena tarjeta → cuenta → unión se rompe con una cuenta real, no entra al grupo. |
| L12-20 | No | Si el aviso no sale, queda el genérico del servidor, como hasta ahora. |
| L12-15 | No | La web vieja sigue funcionando; la nueva solo explica más. |
| L12-8, L12-14, L12-16, L12-18 | No | Si fallan, la persona sigue pudiendo invitar, unirse y entrar como antes. |

## Montaje A · Yala Dev contra staging, iPad (quien invita) + iPhone (quien se une)

**Build:** el primero de 2.2 que lleve este PR, en **Yala Dev**.
**iPad:** Yala Dev con una cuenta con Grupos (la tuya de siempre).
**iPhone:** Yala Dev **recién instalada** (bórrala y vuelve a instalarla). Ten a mano otra cuenta de Apple o Google
**distinta** de la del iPad y **sin grupos**.

### 1 · L12-8 + L12-14 · crear, activar avisos y mandar la invitación (~4 min, iPad)

1. Grupos → **+** → **Nuevo grupo** → «Depa Miraflores» → ✓.
2. **Esperado:** ««Depa Miraflores» está listo» con **Invitar por WhatsApp u otra app** y, debajo, la tarjeta
   **Avisos del grupo** · «Te avisamos cuando alguien apunte un gasto o te pague.» · **Activar avisos**. Ya **no** sale
   la alerta suelta «Notificaciones de grupo» al volver a la lista.
3. Toca **Activar avisos**. Si iOS pregunta, **Permitir**. **Esperado:** la tarjeta dice **Avisos activados**.
4. Toca **Invitar por WhatsApp u otra app** → Mensajes (o WhatsApp) hacia el iPhone.
5. **Esperado:** el mensaje lleva texto, no solo el enlace: «<tu nombre> te invita a «Depa Miraflores» en Yala para
   dividir los gastos. Toca el enlace para entrar; si no tienes Yala, descárgala y vuelve a tocarlo.» y el enlace en la
   línea de abajo.

### 2 · L12-16 + L12-17 · pegar el mensaje entero y ver el grupo antes de la cuenta (~6 min, iPhone)

1. En el iPhone, abre el mensaje y **copia el mensaje entero** (mantén pulsado → Copiar), no solo el enlace.
2. Abre Yala Dev → **Empezar** → **Vengo por un grupo** → **Tengo una invitación**.
3. Toca **Pegar** (el botón bajo el campo). **Esperado:** el campo queda solo con el enlace (sin el texto del mensaje)
   y **Unirme al grupo** se enciende. Si iOS pregunta por el portapapeles, dilo: el botón del sistema no debería.
4. Toca **Unirme al grupo**. **Esperado:** antes de pedir ninguna cuenta, una tarjeta con «Depa Miraflores»,
   «<tu nombre> te invita» y quién está; debajo, «Tu nombre», **Unirme al grupo** y «Después eliges con qué cuenta
   entrar.».
5. Escribe un nombre (p. ej. «Carla») → **Unirme al grupo**. **Esperado:** «Conecta tu cuenta». Entra con la segunda
   cuenta y acepta lo que pida de Grupos.
6. **Esperado:** sin volver a tocar «Unirme», «Conectando con tu grupo…» y después **Solicitud enviada**, que acaba en
   «Te avisaremos cuando te aprueben.» y trae la tarjeta **Avisos del grupo**. Toca **Activar avisos** → Permitir.
7. **No toques Continuar todavía**: deja esa pantalla abierta para el paso 3.

### 3 · L19-1 (en el teléfono) + L12-18 · aceptar y entrar (~5 min, iPad y luego iPhone)

1. En el iPad, abre «Depa Miraflores». **Esperado:** arriba de los gastos, «Carla quiere unirse» con **Revisar**.
2. **Revisar** → Miembros: «Quieren unirse (1)» con la tarjeta de Carla, cuándo abrió el enlace y qué pasa al aceptar.
   **Aceptar** → confirma. **Esperado:** «¿Carla ya tenía cuentas pendientes con el grupo?» → **No, empieza en cero**.
3. En el iPhone, sin tocar nada: **Esperado:** la pantalla cambia sola a «Ya estás en «Depa Miraflores»» con quién está,
   **Apuntar un gasto** y **Ver el grupo**.
4. Toca **Apuntar un gasto**. **Esperado:** se abre el formulario de gasto con «Depa Miraflores» ya elegido. Ciérralo
   sin guardar.

### 4 · L12-20 · el aviso al ser aprobado (~5 min, iPad y iPhone)

1. Repite el paso 2 del iPhone con **otro grupo** creado en el iPad (o borra el iPhone y vuelve a empezar con el
   mismo), pero en «Solicitud enviada» toca **Continuar** y **saca Yala Dev a segundo plano** (vuelve a la pantalla de
   inicio).
2. En el iPad, acepta la solicitud como en el paso 3.
3. **Esperado en el iPhone:** **un solo** aviso, «Ya estás en «<grupo>»» · «Te aprobaron: ya puedes ver sus gastos y
   apuntar los tuyos.». Si además queda «Novedades sobre tu membresía en un grupo», dilo: debería haberse retirado.
4. Toca el aviso. **Esperado:** abre ese grupo.

## Montaje B · después de publicar la web (L12-15)

Necesita la card de Jürgen «Publicar la web de invitación» hecha (la web del PR está en `Web/`, sin desplegar).

1. En un teléfono **sin Yala** (o con Yala borrada), abre en Safari el enlace del mensaje del paso 1.
2. **Esperado:** la tarjeta dice «<nombre> te invita», dos pasos numerados («1 · Descarga Yala», «2 · Vuelve aquí y toca
   «Abrir en Yala»»), **Descargar en App Store** primero y **Abrir en Yala** como segundo botón.
3. Instala Yala, vuelve a la pestaña de Safari y toca **Abrir en Yala**. **Esperado:** la tarjeta del grupo en la app
   trae el nombre del grupo y quién invita (no «Te invitaron a un grupo»).

## Lo que pasó a done en el barrido

| Card | Motivo | Evidencia |
|---|---|---|
| L12-19 | Probado en el simulador y con XCUITest | `UXAudit22Decidido14UITests#test_joinInProgress_tabSaysTheGroupIsOnTheWay`; `antes-4-pestana-conectando` / `despues-4-pestana-en-camino` |
| L12-21 | Solo texto; paridad de los 16 idiomas | `LocalizationParityTests`; `antes-12-enlace-no-valido`, `antes-13-puerta-telefono-con-datos` (el texto nuevo, en los `.strings`) |
| L19-1 | Probado en el simulador y con XCUITest | `UXAudit22Decidido14UITests#test_joinRequest_bannerInsideTheGroup_opensItsCardInMembers`, `GroupMembersAdminUITests`; `antes-6/7` / `despues-6-detalle-solicitud`, `despues-7-miembros-solicitud` |
| L19-2 | Probado en el simulador con XCUITest (seam) y paridad | `UXAudit22Decidido14UITests#test_afterAccepting_theOpeningBalanceQuestionOffersBothAnswers`; `antes-8-saldo-inicial` / `despues-8-cuentas-pendientes` |

## Lo que se queda

| Card | Qué lo retiene (§4) |
|---|---|
| L12-17 | Inicio de sesión real: la cadena tarjeta → cuenta → unión sola (en el simulador, hasta la hoja de cuenta y la unión con sesión fingida) |
| L12-18 | Dos dispositivos: «Ya estás en» tras una aprobación real y «Apuntar un gasto» con el grupo bajado del servidor |
| L12-8 | El permiso real de iOS dentro de las tres pantallas (en el simulador, el estado de la tarjeta con permiso fingido) |
| L12-14 | Compartir de verdad por Mensajes o WhatsApp |
| L12-16 | El botón «Pegar» es el control del sistema y no acepta toques sintéticos (la extracción del enlace, sí: XCUITest) |
| L12-20 | Notificaciones push y dos dispositivos |
| L12-15 | La web publicada (despliegue de Jürgen) |
