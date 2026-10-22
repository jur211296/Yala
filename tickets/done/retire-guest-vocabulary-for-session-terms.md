---
id: retire-guest-vocabulary-for-session-terms
status: done
priority: low
area: "docs, l10n"
created: 2026-09-09
source: "ADR 2026-09-09 «Sesiones — dos ejes» §1"
---

# «Cuenta invitada», «visita» y «sesión secundaria» se retiran del vocabulario: hay sesión privada y sesión en la nube

## Qué pasa

Tres nombres para la misma cosa, y ninguno describe lo que es: «cuenta invitada» / «visita» / «sesión
secundaria» = una sesión en la nube en un móvil cuya sesión privada es de otra persona. El ADR fija
dos términos —**sesión privada** (dispositivo + iCloud privado) y **sesión en la nube** (cuenta
Google/Apple, completa o solo grupos)— y retira los otros tres.

## Lo medido (2026-09-09)

- En textos de usuario casi no vive: **2 de 3.719** strings ES contienen «invitad»
  (`welcome.groups.secondaryTitle` «Aquí estás como invitado», `welcome.groups.secondaryBody`).
- Vive en código, comentarios, `.claude/rules/`, `docs/` y tickets. Es una decisión de glosario, no un
  barrido: los identificadores se retiran con el código en `shell-derives-from-two-session-axes`.
- Sobre el nombre: Jürgen propuso «sesión pública»; Frank propuso «sesión en la nube» («pública» en una
  app de finanzas se lee como «visible»). **Jürgen ratificó «en la nube» el 2026-09-09.**

## Lo que hay que hacer

- [x] Jürgen ratificó el par de nombres el 2026-09-09: **«sesión privada» / «sesión en la nube»**.
- [x] `docs/glosario.md` (bloque manual): entradas para *sesión privada*, *sesión en la nube* (completa /
      solo grupos), *cuenta de grupos asociada*, *equipo*, *bloques [I] [P] [G]*, y una entrada
      histórica para *visita / secundaria / invitada (retirado)* que apunte al ADR.
- [x] `.claude/rules/swiftdata-cloudkit.md` y las demás rules: sustituir el vocabulario donde describa
      comportamiento vigente; donde describa el M1 que se retira, marcarlo como histórico hasta que el
      código se vaya.
- [x] Los dos strings ES y sus 15 hermanos se retiran cuando `WelcomeGroupsGateView` pierda la rama
      secundaria (ticket del barrido); hasta entonces no se tocan. **No se tocaron.**
- [x] Copy nuevo de todo el rediseño (chooser, cierres, «¿Dónde viven tus datos?») escrito con los dos
      términos y revisado contra `BRAND-VOICE.md`. **Lo escriben los pasos 4-10; este ticket les deja la
      fuente y el mecanismo** (ver abajo).

## Lo hecho (2026-09-10, paso 0 del rediseño)

**El checklist llegó desfasado: la mitad del glosario ya existía.** Las entradas de *sesión privada*,
*sesión en la nube*, *cuenta de grupos asociada · equipo*, *[I] · [P] · [G]* y la histórica entraron con
el propio ADR (`6338fca5`, retocadas en `51d4556d`). Se comprobó una a una antes de escribir nada.

Lo que faltaba de verdad era **la decisión de Jürgen sobre los dos vocabularios**, que no estaba en
ningún sitio. Eso es lo que se escribió:

- **`docs/glosario.md`** gana dos entradas: **«los dos vocabularios: dentro ≠ al usuario»** —con los
  strings reales que ya dicen el copy de usuario— y **«Yala completo» ≠ «nube completa»**, que es la
  confusión que el punto 8 del ADR advierte y que ningún documento recogía. La entrada histórica pasa a
  nombrar el ADR con su fecha y a decir que **el código M1 sigue vivo** hasta el paso 12.
- **`.claude/rules/swiftdata-cloudkit.md`**: la sección «Preferencias y fronteras de cuenta» abre con un
  aviso que reparte **por párrafo** (el molde que ya usa la cabecera del fichero para el transporte
  CloudKit muerto): qué vocabulario se retira, **qué código sigue vivo y medido hoy**, cuáles son los
  cuatro párrafos afectados —localizados por su primera frase, no por línea— y qué debe hacer el paso 12
  con ellos. Índice regenerado (`scripts/indexar_doc.py`) y verificado con control positivo.
- **`.claude/rules/l10n.md`** y **`docs/planning/BRAND-VOICE.md` §7** ganan **un puntero de una línea
  cada uno** al glosario. No copian la tabla: duplicarla es como divergen.

### Lo medido hoy, contra este árbol

| Afirmación | Medido |
|---|---|
| «2 de 3.719 strings ES contienen "invitad"» (ticket, 9-sep) | **2 de 4.074** hoy: `welcome.groups.secondaryTitle` y `…Body`. Sigue siendo 2 |
| «y sus 15 hermanos» (ticket) | **Cierto, y son los otros 15 locales**, no otras keys: la app tiene **16 locales** y las dos keys están en los 16. ⇒ el paso 12 retira **32 strings**, no 2 (lo pide `LocalizationParityTests`) |
| El copy de usuario no usa jerga interna | **Cero** de los 4.074 strings ES dice «sesión privada», «sesión en la nube», «solo grupos», «sesión secundaria» o «visita» |
| «Yala completo» es copy vivo | **5 strings ES**: `groups.activate.title`, tres nudges (`groups.nudge.invited*`) y `groups.bridge.upsellGroupInviteSettlement` |
| El código M1 sigue vivo | `SecondarySessionStore` en **65 ficheros** (44 en `Yala/`), `SessionDefaults` en **60** |
| El vocabulario en las rules | **8 líneas, todas en `swiftdata-cloudkit.md`**, todas dentro de una sola sección. `testing.md` solo tiene identificadores de seed (`grupos-invitado`), que son código |

### Dos decisiones de alcance, tomadas aquí

Ninguna toca producto; las dos se registran por si alguien las discute más tarde.

1. **`.claude/rules/l10n.md` y `BRAND-VOICE.md` §7 entran, con un puntero.** Jürgen mandó que «el glosario
   registre la correspondencia», y el glosario la registra. Pero el glosario **no se carga solo**: la rule
   de l10n sí, al tocar cualquier `.strings`, que es justo el instante en que alguien iría a «corregir» el
   copy. Y `BRAND-VOICE.md` §7 ya **es** una tabla «término interno → cómo decirlo al usuario»: dejarla sin
   las sesiones era dejar el hueco abierto donde más se mira.
2. **`docs/aprendizajes-tecnicos.md`, `docs/flows/`, `docs/modo-nube/` y `docs/DECISIONS.md` NO se tocan.**
   El ticket nombra el glosario y las rules. Los otros describen el código de hoy —que sigue vivo— o son
   registro histórico, y una decisión no se reescribe: se supersede. El paso 12 ya lleva en su checklist
   el barrido de comentarios y docblocks cuando el símbolo desaparezca.

### Para el paso 12 (`shell-derives-from-two-session-axes`)

Su criterio de aceptación pide `docs/glosario.md` y `.claude/rules/swiftdata-cloudkit.md` «sin
"secundaria", "visita" ni "invitada" **como estados vivos**». Ese matiz importa y hay que respetarlo: la
entrada histórica del glosario y las cuatro lecciones de la rule **se quedan**, con la redacción
actualizada. Su propia decisión de Jürgen lo dice — «lo que merezca sobrevivir va a `.claude/rules/` o a
`docs/aprendizajes-tecnicos.md`». Las cuatro se pagaron con incidentes de producción.

## Fuera de alcance

Renombrar identificadores de código por su cuenta: van con el código que los usa.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

- **Este ticket SE ADELANTA: pasa a ser el paso 0 del runbook**, antes que ningún otro. Motivo: los
  tickets 4-10 escriben copy nuevo y con el orden viejo lo habrían escrito con el glosario sin fijar,
  cada uno inventando su palabra. Es documentación pura, así que va directo a `2.1` sin gate y no
  bloquea a nadie. El runbook queda actualizado con este cambio.
- **Conviven dos vocabularios a propósito, y el glosario lo deja escrito.** Dentro (documentación,
  código, tickets) se dice **«sesión privada»** y **«sesión en la nube»**; al usuario se le sigue
  hablando de **dónde viven sus datos** («Tu cuenta en tu iCloud privado» / «Tu cuenta en la nube»).
  El glosario tiene que registrar esa correspondencia explícitamente, para que ninguna sesión futura
  «corrija» el copy de producto hacia la jerga interna. No reescribas copy que ya funciona.
- **[I], [P] y [G] entran al glosario**, con su nombre largo y su letra: identidad en la nube,
  onboarding personal, alta de grupos. Son jerga viva del ADR y de los 13 tickets.
