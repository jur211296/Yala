---
name: qa-guiado
description: QA guiado en vivo con Jürgen sobre su iPhone de pruebas — un paso a la vez, midiendo desde la Mac, con card por cada bug y la cuenta al día. Úsala cuando Jürgen vaya a hacer QA de una versión o pida que lo guíes en la tanda.
---

# QA guiado con Jürgen

Va **después** de un `/barrido-qa`, en otra sesión. La tanda que el barrido dejó
(`docs/qa/tanda-qa-jurgen-<versión>.md`) es el guion: aquí se ejecuta con él delante. Si no hay barrido posterior al
último merge grande, dilo y propón lanzarlo antes; la tanda sin barrido le hace perder la tarde en lo que el simulador
ya podía cerrar.

## 1. Montaje, antes del primer paso

Todo esto lo haces tú, y se lo cuentas en dos líneas:

1. **Dispositivos:** `xcrun devicectl list devices`. Identifica el iPhone de QA y el iPad por nombre y UDID. **El
   iPhone personal de Jürgen, con datos reales, queda fuera** salvo que él lo pida para una prueba concreta.
2. **Qué build lleva cada arreglo:** el último TestFlight frente a los PRs mergeados después. Lo que no está en
   TestFlight se prueba en **Yala Dev** compilado desde la rama de release e instalado con `devicectl`.
3. **Datos de prueba** generados de antemano en `~/Claude/entregas/<slug>/`: CSV, PDFs, recibos e imágenes, con su
   forma de llegar al teléfono (AirDrop: imágenes a Fotos, el resto a Archivos).
4. **Acceso a staging**, para verificar en la base lo que la prueba dice que se escribió.
5. **Orden de la sesión**, que se cuenta en «Llevamos N de M»: primero Yala Dev contra staging en el iPhone de QA,
   luego TestFlight en el iPhone de QA, luego dos dispositivos, y al final y aparte lo que no pide iPhone (App Store
   Connect, consolas).

Escribe las decisiones del montaje en el `## Paso 0` del encargo.

## 2. Cómo se le habla

- **Un paso a la vez.** Das el paso y esperas su respuesta. El siguiente paso depende de lo que él vio.
- Español neutro latinoamericano, frases cortas, lenguaje de usuario. Pasos numerados con los textos reales de la app:
  cada ruta se comprueba en el código y en `es.lproj/Localizable.strings` antes de dársela.
- Él no lee documentos durante la sesión: todo lo que necesita está en el chat.
- **Accesibilidad no se prueba.** Texto grande, tamaños y VoiceOver se dan por buenos: él confía en el código.
- Cuando el paso exige elegir entre un botón seguro y uno destructivo, dile cuál tocar **antes** de que lo vea.
- Si pregunta algo en medio, se contesta y se vuelve al paso donde estaba.

## 3. Mirar desde la Mac

Su respuesta dice lo que ve; tú mides lo que pasó por debajo:

- **Consola:** abre la app tú,
  `xcrun devicectl device process launch --device <UDID> --terminate-existing --console <bundle> > $S/consoleN.log`,
  en segundo plano. En los momentos clave pídele «ciérrala y no la abras, la abro yo».
- **Datos:** copia el store
  (`xcrun devicectl device copy from --domain-type appGroupDataContainer …`) y consúltalo con `sqlite3`. Un «creo que
  está bien» se confirma así.
- **Staging:** SQL por la Management API de Supabase.
- Para tocar la pantalla del iPhone físico no hay herramienta: los toques son de Jürgen.

## 4. Cada resultado

**Pasa:**
1. `tablero mover <id> --a done --agente frank`. Si el escenario no tiene card, apunta su ticket para el cierre.
2. Una línea en `$S/resultados.txt`.
3. Le das la cuenta: «Llevamos N de M».

**Falla:**
1. **¿Bug o prueba mal planteada?** Lee el código. Si la prueba era imposible, como un pago «con fecha de ayer» en un
   editor con `minDate: today`, adáptala, díselo y sigue.
2. Si es bug, busca duplicados: `tablero listar --proyecto yala` y `tickets/`.
3. Card con `--proyecto yala --asignado frank --estado backlog --version <v>`. En el contexto, separa lo **medido** de
   lo **inferido**. Si el arreglo pide una decisión de producto, ponla en `--pregunta` con opciones A/B/C.
4. Díselo en lenguaje de usuario: qué le pasaría a una persona real, el nombre de la card y sus opciones. Luego sigue con
   la prueba.

`--nota` y `--enlace` del tablero **sustituyen** el campo entero: antes de editar, `tablero ver <id>` y repite lo que
había.

## 5. Cierre

Cuando la tanda termina, o cuando Jürgen dice «paramos aquí»:

1. Tickets sin card que pasaron: `git mv tickets/qa/X.md tickets/done/` con la línea
   «Cerrado en el QA guiado AAAA-MM-DD: <qué se vio>». Los que quedaron a medias siguen en `qa`, con una nota de qué paso
   falta. `docs/TICKETS.md` al día.
2. En el encargo, `## Resultado`: pasaron, fallaron con su card y pendientes con dónde se quedaron.
3. Resumen a Jürgen en este orden: **Necesita de ti** (decisiones de las cards nuevas) · **Cambiado** (cards y tickets
   movidos) · **Encontrado** (bugs, con su card). Los documentos, con `SendUserFile`.
4. `/cerrar-total`.

**Terminado** es esto: cada escenario de la tanda tiene uno de tres estados (pasó, falló con card o pendiente con su
paso), y la cuenta del resumen coincide con `resultados.txt`.

## Trampas medidas

- **El contenedor del App Group sobrevive a borrar la app** si queda instalada otra app que declara el mismo grupo: el
  build Debug de «Yala» declara también `group.….yala.dev`. Para una instalación limpia de Yala Dev, borra las dos.
  Medido el 2026-10-14: 9 gastos de grupo viejos dispararon avisos que no eran bugs.
- **Apagar iCloud Drive vacía la copia local**: iOS la purga y Yala la re-importa al volver a encenderlo. Si un
  escenario lo pide, el aviso de datos vacíos es esperable mientras no se arregle la card `i1o5`.
