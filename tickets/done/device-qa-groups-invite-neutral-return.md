---
id: device-qa-groups-invite-neutral-return
status: done
priority: high
area: "modo-nube, groups, onboarding"
created: 2026-09-11
source: "`groups-invite-on-a-mirrored-store-crosses-data` (2026-09-11)"
updated: 2026-09-23
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - pide dos Apple ID, dos personas y un tercer aparato
---

# Device-QA · aceptar una invitación sobre un teléfono que ya espeja iCloud

**NO es simulable, y por dos razones distintas.** (1) Lo que hay que comprobar es que el iCloud del DUEÑO
no reciba nada, y el simulador no tiene cuenta de iCloud: el store de UITest monta
`cloudKitDatabase: .none`, así que no hay espejo que pueda cruzar nada. (2) El montaje necesita **dos
Apple IDs y dos personas** —una con datos en su iCloud, otra con una invitación— y la comprobación final
ocurre en un TERCER sitio: el otro dispositivo del dueño.

Lo que sí está cubierto por unit: la decisión (16 celdas), el desvío desde `drive` en sus cinco orígenes,
la durabilidad del intent a través del wipe y el cableado
(`YalaTests/Groups/GroupInviteNeutralGateTests.swift`, 21 casos en 4 suites).

## Montaje

- **Teléfono A** (el que se presta): Apple ID **del dueño**, con datos personales ya en su iCloud. Déjalo
  en el estado B de la matriz: instala Yala, elige «Soy nuevo → privado» o «Restaurar de iCloud», deja que
  el espejo baje el corpus, y **vuelve atrás sin terminar el onboarding** (o mata la app). Al reabrir
  tienes que ver el Welcome o el onboarding, no el Panel.
- **Teléfono B** (o el iPad del dueño): mismo Apple ID que A, con Yala instalada y su sesión privada
  viva. Es el testigo: aquí es donde el daño se vería.
- Una **invitación a un grupo** creada desde una tercera cuenta de Yala, con su enlace a mano.

## Recorridos

**1 · El caso del ticket (AC 1).** En el teléfono A, con el Welcome delante, abre el enlace de invitación.
→ Tiene que salir **«Antes de unirte, este teléfono queda en blanco»**, con dos botones: «Continuar y
  borrar» (destructivo, arriba) y «Volver».
→ **Toca «Volver» primero.** No puede haberse borrado nada: vuelve al chooser, mata la app, reábrela y
  comprueba que los datos del dueño siguen ahí.
→ Ahora vuelve a abrir el enlace y toca **«Continuar y borrar»**. Verás el progreso («Estamos subiendo tus
  últimos cambios a iCloud…») y después el terminal que pide reabrir Yala.
→ Reabre. **La hoja «Unirme al grupo» tiene que salir sola**, con el nombre del grupo. Ése es el criterio
  que la key durable existe para cumplir: si en vez de eso aterrizas en el Welcome, la invitación se
  perdió en el borrado.
→ Únete y anota **dos gastos** en el grupo.

**2 · El iCloud del dueño, intacto (el criterio que no se puede simular).** En el **teléfono B**:
→ Los datos personales del dueño **siguen todos**. Cuenta las transacciones: el mismo número que antes.
→ **Ninguno de los dos gastos del grupo aparece**, ni en el Panel ni en Registros. Espera unos minutos y
  vuelve a mirar: el espejo puede tardar. Si aparecen, el arreglo no funcionó y es el bug entero.

**3 · Lo que no llegó a subir (AC 4).** Repite el montaje de A. Antes de abrir el enlace, **pon el teléfono
en modo avión** y crea una transacción nueva. Quita el modo avión y abre el enlace.
→ El aviso de la espera («Aún faltan cambios por subir a iCloud») puede salir o no según lo rápido que
  exporte. Si sale, toca **«Esperar»**.
→ Cuando el borrado termine y reabras, comprueba **en el teléfono B** que esa transacción llegó.

**4 · El invitado limpio no paga nada (AC 3).** Teléfono con Yala **recién instalada** (o borrada del todo)
y sin haber tocado el Welcome.
→ Abre un enlace de invitación. **No puede salir ninguna pantalla de borrado.** El recorrido es el de
  siempre: sign-in de Grupos → consentimiento → hoja «Unirme». Es la población mayoritaria y no puede
  pagar una pantalla por un teléfono que no tiene el problema.

**5 · La sesión privada viva NO se toca (fila C de la matriz).** En el **teléfono B**, con la sesión
privada del dueño abierta y el onboarding completado, abre el mismo enlace de invitación.
→ **No puede salir la pantalla de borrado.** El recorrido es el de asociar una cuenta de grupos. Si aquí
  sale la pantalla, el término de la sesión privada está roto y el arreglo le vacía el teléfono al dueño:
  es el fallo más caro de todo este cambio.

**6 · Sin copia en iCloud.** Teléfono A con iCloud **desactivado para Yala** (Ajustes de iOS → tu nombre →
iCloud → Apps que usan iCloud → Yala, apagado) y con datos locales.
→ Al abrir el enlace, el cuerpo del aviso tiene que ser el otro: **«no encontramos una copia en iCloud …
  no se podrán recuperar»**. Comprueba que lo dice con esas palabras: prometer que los datos están a salvo
  cuando no lo están es lo que esa segunda variante existe para evitar.

**7 · Kill a mitad.** Repite el 1 y, en cuanto veas el terminal «reabre Yala», **mata la app desde el
App Switcher** sin reabrirla desde el aviso.
→ Vuelve a abrirla desde el icono. El borrado tiene que haberse hecho igual y la hoja del invitado tiene
  que salir. No puede quedarse un progreso a medias ni el corpus del dueño a medio borrar.

## Qué anotar

Para cada recorrido: qué viste, en qué orden, y una captura del teléfono B en el recorrido 2. Si algo se
desvía, apunta el estado exacto del teléfono A antes de empezar (onboarding completado o no, iCloud
activado o no, datos locales sí o no) — es lo que decide qué rama de la puerta corre.

## Corrección al guion · 2026-09-16 (barrido de QA)

- **Montaje (:25):** «Soy nuevo → privado» y «Restaurar de iCloud» ya no existen con ese texto. Hoy son
  «Es mi primera vez en Yala» y «Ya tengo una cuenta» → «Restaurar desde iCloud».
- **«21 casos» (:18-20):** hoy son 29 `@Test`.
- **Absorbe desde hoy a `groups-invite-on-a-mirrored-store-crosses-data`** (cerrado): su prueba es el recorrido 2.
- El resto de textos del guion existe tal cual («Antes de unirte, este teléfono queda en blanco»,
  «Continuar y borrar», «Unirme al grupo»…).

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Pide dos Apple ID, dos personas y un tercer aparato de testigo, para un caso raro (abrir una invitación a mitad del onboarding). Lo cubre `GroupInviteNeutralGateTests`.
