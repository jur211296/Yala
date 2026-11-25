Yala
# Build 9: arreglar la migración de la Bandeja desde 2.2 que deja el PR en rojo
---
toca: YalaTests/BandejaUnirAlLlegar/,Yala/Models/InboxDraft.swift,Yala/Utils/SwiftDataConfiguration.swift,tickets/backlog/2026-11-25-build-9-migracion-bandeja-22.md,tickets/done/2026-11-25-build-9-migracion-bandeja-22.md
esfuerzo: high
cierre: cierra-sola
---

Card del tablero (2.3, prioridad alta): **tablero-build-9-la-prueba-de-migracion-de-la-ban-imji**. Jürgen autorizó este arreglo el 25-nov a las 8:25 Lima.

## Contexto
El PR #1171 (https://github.com/jur211296/Yala/pull/1171), rama `encargo/2026-11-25-barrido-y-testflight-2-3-build-9` hacia `2.3`, está abierto, en auto-merge y BLOQUEADO. Trae el número de build 9, los esquemas de iCloud de Producción al día (`Cloudkit Schemas/yala-production.ckdb` y `yala_dev-production.ckdb`, con el campo nuevo `CD_InboxDraft.CD_joinRecordRaw` ya dado de alta en Producción) y la guía de novedades. **La build 9 ya está en TestFlight**: lo que falta es que el PR entre en 2.3.

El check `tests` falla en la tanda 3 de unit: `YalaTests/BandejaUnirMigracion22Tests/unaBaseDe22_abreConElModeloDeHoy_conSusBorradores()`, y sigue en rojo al repetirla. Run: https://github.com/jur211296/Yala/actions/runs/45611092032. En `2.3` la misma prueba pasa.

Causa probable (no confirmada): la prueba arma «el modelo de 2.2» quitando del modelo de hoy los atributos que no están en `Cloudkit Schemas/yala-production.ckdb`, y su control exige que eso quite `InboxDraft.joinRecordRaw`. El PR #1171 agrega `CD_joinRecordRaw` a ese esquema de Producción, así que ya no se quita nada y el control `removed["InboxDraft"]?.contains("joinRecordRaw") == true` falla. Si es eso, se rompió la prueba porque se apoyaba en el esquema vivo de Producción, y no la migración. Hay que confirmarlo y no darlo por hecho.

## Qué se pide
1. Trabaja **sobre la rama del PR 1171**, no en una rama nueva: haz checkout de `encargo/2026-11-25-barrido-y-testflight-2-3-build-9` y empuja ahí. Si tu worktree nace sobre otra rama, cámbiate a esa.
2. Reproduce la prueba en local y lee la aserción exacta que falla.
3. **Primero contra la versión publicada** (lección fija: ante un fallo grave se mide primero contra lo publicado). Comprueba que una base real de 2.2 abre bien con el código de la build 9 y conserva sus borradores de la Bandeja. Puede ser la de la 2.2 de la App Store en el iPhone 14 por DeviceMCP, o una base creada con el código del tag de 2.2. Di en el cierre cómo lo mediste.
4. Arregla la causa:
   - **Si es la prueba**, que el «modelo de 2.2» deje de depender del esquema vivo de Producción. Por ejemplo, congela el esquema de Producción de la 2.2 (el que había antes de este PR) en un archivo de la prueba dentro de `YalaTests/BandejaUnirAlLlegar/` o reconstrúyelo desde el tag de 2.2. Así la prueba sigue probando de verdad la migración de una base sin `joinRecordRaw`, y su control sigue en pie.
   - **Si es un bug real de la migración**, arregla el código. Es **crítico**, porque la build 9 ya está en TestFlight y alguien que actualice desde 2.2 podría perder datos. Dilo en el cierre, arriba y con claridad: qué pasa, a quién le afecta y si hay que retirar la build 9 o subir una 10.
5. Corre la prueba arreglada y las de `YalaTests/CloudSync/PersonalCloudKitSchemaParityTests.swift`, solo para confirmar que siguen verdes. No las edites salvo que hagan falta, y si es así, dilo.
6. Ticket: crea `tickets/backlog/2026-11-25-build-9-migracion-bandeja-22.md` y, al cerrar, muévelo a `tickets/done/`.
7. Deja el PR #1171 en auto-merge y cierra sin esperar el CI.
8. El entregable es un artifact visual de Claude. Debe mostrar la causa, cómo se midió contra la 2.2 publicada y el antes y el después de la prueba. Enlázalo en el cierre.

Pruebas en simulador o dispositivo:
  - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
  - Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
  - Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
  - Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva); nada de bucles de 10 min ni comandos que se pasen del límite y queden en segundo plano a ciegas.
  - Antes de compilar en iOS mira la carga: si otra sesión compila con xcodebuild en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.

Build iOS: pipeline serial (limpiar, compilar con `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, probar, apagarlo). Usa el iPhone 14 por DeviceMCP. Un segundo simulador, solo en la Max. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Solo lo de `toca:`: la carpeta de la prueba de la Bandeja, el modelo `InboxDraft`, la configuración de SwiftData si de verdad hace falta y el ticket. Nunca `Yala/`, `YalaTests/` ni `tickets/` enteros, ni `Yala/Resources`.
- No cambies los esquemas `Cloudkit Schemas/*.ckdb` del PR: reflejan Producción tal como está hoy.
- No toques el número de build ni la guía de novedades.
- No subas otra build a TestFlight ni despliegues nada.
- Sin firma de IA en commits ni en el PR.

## Cómo se sabe que está bien
- La prueba de migración desde 2.2 pasa en local y sigue probando una base sin `joinRecordRaw`.
- Una base 2.2 real abre con la build 9 sin perder borradores, y el cierre dice cómo se midió.
- La causa queda nombrada en el commit y en el cierre, y se dice claramente si fue la prueba o un bug.
- El PR #1171 queda en auto-merge.
- Cierre con `/cerrar-total`, con las secciones «Saltado o asumido sin preguntar» y «Decidido sin consultar». Todo en español neutro latinoamericano.
