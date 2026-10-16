---
id: reverse-to-icloud-merges-prior-icloud-data-without-asking
status: qa
priority: high
area: "modo-nube, migración"
created: 2026-10-15
source: "QA guiado del 2026-10-15 (C3 + A2, iPhone de QA) · card tablero-volver-a-icloud-con-una-cuenta-nacida-en-4nt6"
updated: 2026-10-16
qa-status: needs-testing
qa-notes: simulador cubierto con seams; falta el iPhone con un iCloud real con datos previos
---

# Volver a iCloud con una cuenta nacida en la nube suma, sin avisar, lo que ya había en ese iCloud

## Lo que pasó, en lenguaje de usuario

Creo mi cuenta en la nube en un iPhone. Más tarde toco «Volver a iCloud» y el aviso me dice «No perderás nada». La
vuelta termina bien, pero en mis datos aparecen cosas que no son mías: en el QA del 15-oct, 25 movimientos de la cuenta
más 9 gastos de grupo del 18-jul de OTRA cuenta de Yala que había usado ese iPhone. Los gastos de grupo salen en la
Bandeja sin grupo que los explique, y en Grupos la app me manda al onboarding.

## Por qué pasaba

La vuelta monta el espejo de CloudKit sobre la zona del Apple ID, y el espejo baja todo lo que encuentra. El código daba
por hecho que una cuenta nacida en la nube «nunca tuvo zona» (`StorageModePersistence.bornCloudKey`): es verdad de la
cuenta, no del iCloud del teléfono.

## Decisión de Jürgen (2026-10-15): opción A

Si el iCloud del teléfono ya tiene datos de Yala, avisar ANTES de la vuelta y dejar elegir: sumarlos o empezar sin
ellos. El aviso deja de decir solo «No perderás nada».

## Lo que se hizo

- El botón «Volver a iCloud» de un teléfono nacido en la nube pregunta primero a iCloud
  (`CloudMigrationController.checkICloudBeforeReverse`). Nada ajeno → las confirmaciones de siempre. Algo ajeno → el
  aviso «Tu iCloud ya tiene datos de Yala» con las cifras y dos salidas. Sin respuesta → «No pudimos revisar tu iCloud»
  y la vuelta no empieza. Sin cuenta de iCloud → «Abre iCloud en este iPhone» y tampoco empieza: la vuelta se quedaría
  esperando a que la persona lo abra, y entonces el espejo sumaría sin preguntar.
- «Ajeno» es lo que el espejo bajaría como fila NUEVA: registros de la zona del espejo de las entidades personales (menos
  tipos de cambio) cuyo `recordName` no está en los metadatos del espejo del store local (`ANSCKRECORDMETADATA`). La copia
  propia que deja una vuelta anterior a medias no cuenta. La sonda vieja (`ICloudPersonalCorpus`) no servía: deja fuera los
  movimientos de grupo, que eran justo lo único que había en el QA. Los metadatos se leen ESTRICTOS: una lectura cortada
  del SQLite es «no se sabe», nunca un conjunto parcial (un conjunto parcial haría pasar la copia propia por ajena).
- «Empezar sin ellos» borra de iCloud solo lo ajeno, registro a registro y página a página, y nunca la zona: con
  metadatos locales del espejo, remontar sobre una zona borrada podría purgar el store local. Se borra al confirmar, tras
  comprobar que la vuelta puede empezar (nube activa, elegible, journal legible, sin una salida anterior a medias); si el
  borrado no termina, la vuelta no empieza.
- Canarios `cloudReverseICloudPriorDataChecked` (`found|none|noAccount|failed:<motivo>`) y
  `cloudReverseICloudPriorDataChoice` (`merge|discard|discardFailed:<motivo>`).

## Decidido sobre las filas de grupo que se suman

Se suman tal cual. No se borran de iCloud al sumar: pueden ser las de otro dispositivo con ese Apple ID que sí tiene esos
grupos, y borrarlas se las quitaría a él, incluidas transacciones reales aprobadas. El aviso las cuenta aparte y dice que
pueden llegar sin su grupo. Que después no se puedan descartar de la Bandeja va en
`prior-icloud-group-records-summed-without-their-group`.

## Fuera de alcance, con ticket

- Una cuenta MIGRADA no pregunta: su zona es su propio corpus y la vuelta está construida sobre él. Si otro dispositivo del
  mismo Apple ID escribió ahí después de la migración, se suma igual: `reverse-of-a-migrated-account-sums-records-written-after-the-migration`.
- Lo que otro dispositivo escriba en la zona entre la pregunta y el montaje del espejo se suma sin aviso. Normalmente son
  minutos, pero si la vuelta se para antes de montar puede ser días (las fases previas tienen techo de 72 h y retomar no
  vuelve a preguntar). Inferido, y de la misma familia que el anterior: va en ese ticket.
- Una vuelta anterior que ya importó lo ajeno y salió deja esas filas con metadato local: cuentan como propias y la pregunta
  no las ve. La mezcla ya había ocurrido; es `reverse-exit-leaves-a-partial-copy-in-icloud`.
- Un `CD_CloudMigrationMarker` ajeno ni se cuenta ni se borra (es de la migración de otra cuenta). Confianza baja de que
  moleste; sin ticket.
- Los plurales con cifra 1 («1 cuentas») vienen de las claves del Welcome que se reutilizan; no hay `.stringsdict` en esa
  familia.
- Un iCloud con una copia propia enorme puede agotar el plazo de 60 s de la pregunta y quedarse en «No pudimos revisar».
  El borrado ya avanza por páginas, así que un reintento progresa.
- `reverse-cancel-pushes-what-the-mirror-imported-during-the-wait`: si la persona suma y luego cancela la vuelta durante la
  espera, lo importado sube a la cuenta. Ya existía.

## Cómo se probó

- Unit (27): decisión y texto (`ReverseICloudPriorDataLogicTests`), recuento con `CKRecord` fabricados incluido el caso del
  QA (`ICloudForeignTallyTests`), lector de metadatos con un SQLite a mano (`MirroredRecordNamesTests`) y cableado por
  source-scan (`ReverseICloudPriorDataWiringTests`).
- XCUITest (5, `ReverseICloudPriorDataUITests`) con dos seams que fingen la entrada: `-uitest-born-cloud-storage` y
  `-uitest-reverse-prior-icloud <found|foundGroups|none|failed>`, más `-uitest-reverse-prior-icloud-wipe-fails`.
- Review adversarial con tres lentes (datos, flujo de pantalla, tests y copy): todo lo sólido se corrigió en el mismo PR
  (lectura estricta de metadatos, sin iCloud no se empieza, comprobaciones antes del borrado, doble toque, reintento,
  borrado por páginas, frase del borrado que prometía de más, tests que faltaban).
- Mutantes: ver el PR.

## Device-QA (Jürgen, iPhone de QA)

CloudKit no existe en el simulador: lo que falta es la pregunta y el borrado contra un iCloud real.

1. Instala el build de este cambio (Yala Dev) en el iPhone de QA. Su iCloud ya tiene datos de Yala de antes (los del 15-oct).
2. Si hay sesión, Ajustes → Cerrar sesión. En el Welcome: «Es mi primera vez» → «Tu cuenta en la nube» → entra con una
   cuenta de Google nueva (A). Crea 2 registros.
3. Ajustes → «¿Dónde viven tus datos?» → «Volver a iCloud». Tiene que salir «Revisando tu iCloud…» y después «Tu iCloud ya
   tiene datos de Yala» con cifras. Apúntalas.
4. «Sumarlos a mis datos» → «Sí, volver a iCloud». Espera a que termine: en Registros, tus 2 y los de antes.
5. Ajustes → Cerrar sesión. Welcome → «Es mi primera vez» → «Tu cuenta en la nube» → otra cuenta de Google nueva (B). Crea 1
   registro.
6. «Volver a iCloud» otra vez: el aviso tiene que salir de nuevo.
7. «Empezar sin ellos» → «Borrar y volver a iCloud». Espera a que termine.
8. En Registros y en la Bandeja: solo el registro de B. Nada de antes, nada de A, ningún gasto de grupo.

Si en el paso 3 sale siempre «No pudimos revisar tu iCloud» con buena conexión, es el punto sin medir de la lista de campos
de la sonda (`ICloudPersonalCorpusProbe.foreignDesiredKeys`): dímelo y paso al plan B (contar sin campos).

## Barrido de QA · 2026-10-16

Barrido de QA 2026-10-16 · se queda: §4 iCloud real con datos previos y entrada real con Google en staging. Las ramas de la decisión, el borrado y los fallos los fijan 33 unitarios, 7 XCUITest y 11 mutantes (#517). Prueba A · 4nt6 de `docs/qa/tanda-qa-jurgen-2.1.md`, en el mismo montaje que A · C4.
