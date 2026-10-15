---
id: session-redesign-web-and-store-copy
status: qa
priority: high
area: "web, marketing, legal"
created: 2026-09-09
updated: 2026-10-15
source: "ADR 2026-09-09 «Sesiones — dos ejes» — consecuencias · partido de after-session-redesign-review-widgets-siri-applepay-and-web-copy por decisión de Jürgen (2026-09-09)"
---

# La web, la política y la ficha dicen que Grupos viaja por iCloud; con el rediseño Grupos es una cuenta en la nube

## Por qué existe este ticket aparte

Salió de la mitad «fuera del territorio de Frank» del ticket
`after-session-redesign-review-widgets-siri-applepay-and-web-copy`. **Es trabajo de Lola**
(`marketing/`, `Web/`): Frank no entra ahí. Se separa para que cada mitad se cierre por su cuenta y el
runbook del rediseño no quede esperando a otro territorio.

## Lo que cambia, en una frase

Hasta hoy Grupos sincronizaba **por CloudKit Sharing** —«por tu iCloud, no por servidores nuestros»—.
Con el ADR de sesiones, **Grupos es una mini-app que vive en el backend de Yala** y necesita una cuenta
Google/Apple. Lo personal es lo que puede seguir siendo privado (iCloud) o estar en la nube.

## Lo que hay que revisar

- [x] **Política de privacidad** y **términos**: dicen que los datos de Grupos no pasan por servidores
      propios. Con el rediseño es falso.
- [x] **La web** y la **FAQ**: misma afirmación. Referencia medida: revisión web del 2026-09-03, L2,
      `Web/REVISION-WEB-UX-A11Y-2026-09-03.md:95`.
- [ ] **Ficha de la App Store** en 7 idiomas y **capturas**: la elección privado / nube y Grupos como
      mini-app, tal y como queden al terminar el rediseño.
- [ ] **Etiquetas de privacidad** de App Store Connect: comprobar que declaran lo que recoge la cuenta en
      la nube (puede que ya lo hagan desde el Modo Nube; **medir**, no suponer).

## Decisión de Jürgen (2026-09-09): esto BLOQUEA la publicación

**La política de privacidad y los términos tienen que estar corregidos ANTES de que el rediseño llegue a
la App Store.** Es una afirmación sobre dónde viven los datos de la gente y no puede ser falsa ni un día.
La web comercial, la FAQ, la ficha y las capturas **no** bloquean: se ponen al día en cuanto se pueda.

## Cuándo

Los textos se pueden ir preparando en cuanto el rediseño esté cerrado en código
(`shell-derives-from-two-session-axes` en `2.1`); lo que no se puede es publicar la app antes de que
política y términos estén corregidos.

## Relacionado

- `after-session-redesign-review-widgets-siri-applepay-and-web-copy` — la mitad de Frank.
- ADR `docs/DECISIONS.md` → «[2026-09-09] Sesiones — dos ejes», sección «Fuera de este repo-territorio».

## Hecho (2026-10-12, encargo `textos-legales-2-1`)

Frank reescribió la política y los términos en los seis idiomas, con fecha «Octubre 2026», por
excepción de Jürgen a «Web/ es de Lola» solo para esta tarea. Cada afirmación nueva lleva su cita
`fichero:línea` en la descripción del PR. Además: `faq1A`, `faq7A`, `faq9A`, `v3Priv1`, `v3Priv3`,
`v3CtaNote`, `pricingFree1` y `v3FreeDesc`. Nada desplegado.

## Guion de QA (Lola + Jürgen)

1. Leer el PR: la tabla «antes / después» y la lista de lo no verificado.
2. Aprobar el PR (basta Jürgen, sin abogado) y mergear.
3. En Vercel, cambiar la rama de producción de `1.0` a `2.1` y esperar al despliegue.
4. Abrir `https://yala-app.pe/privacy` y `https://yala-app.pe/terms`: arriba debe decir
   «Última actualización: Octubre 2026» y la política tiene 15 secciones. Repetir con `/en/privacy`.
5. Comprobar que ya no sale el texto viejo: `curl -sL https://yala-app.pe/privacy | grep -c "Supabase"`
   da más de 0. (El `grep -c CloudKit` de la checklist ya no sirve: la política nueva nombra CloudKit dos veces,
   para el modo privado y para los grupos antiguos.)

**Lo que este PR no cubre de este ticket** (sigue pendiente y no deja pasar el QA hasta que esté): la
ficha de la App Store en 7 idiomas y las capturas (Lola), y las etiquetas de privacidad de App Store
Connect (Jürgen, `docs/RELEASE-CHECKLIST-2.1.md` §1).

## Barrido de QA · 2026-10-15

Barrido de QA 2026-10-15 · se queda: se queda sin iPhone (E · G2): ficha de Lola en 7 idiomas y la rama de producción de Vercel. Guion en `docs/qa/tanda-qa-jurgen-2.1.md`.
