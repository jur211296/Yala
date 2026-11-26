Yala
# Maquetas: deudas directas con personas fuera de grupos
---
toca: docs/propuestas/deudas-directas-con-personas/,tickets/backlog/2026-11-26-deudas-directas-con-personas.md,tickets/done/2026-11-26-deudas-directas-con-personas.md
esfuerzo: medium
cierre: propuesta-visual
release: no
pruebas-ui: no
---

Pedido de Jürgen (26-nov, 10:15 Lima): «Lo otro que es súper importante y debe ir en 2.3 y me había olvidado es que en Splitwise puedes tener deudas con personas, fuera de grupos. Por ejemplo directamente poner "me debe X /2 esta persona" pero no sé cómo lo haríamos, porque en Splitwise se requiere que el usuario ya tenga cuenta o la cree y acepte. Aunque ya tenemos modo nube obligatorio, podríamos hacerlo con correo? […] maquetemos lo segundo.» Sesión SOLO de propuesta visual y diseño funcional/técnico: no se implementa código de producto. Va para 2.3.

## Contexto
- Card del tablero de Yala 2.3 que cubre esta sesión (búscala por título con `tablero listar --proyecto Yala`): «Grupos: deudas directas con personas fuera de grupos (2.3)». No crees otra card para lo mismo.
- Cards relacionadas, para aclarar el solape (no las cierres ni las edites salvo una nota con el link del artifact):
  - «Préstamos con personas: lo que te deben y lo que debes a amigos o familia» (2.4, estilo Vuelto: préstamos de plata, abonos, sin interés). Su ticket es `tickets/backlog/debt-tracking.md` (solo lectura). Di en la propuesta si conviene fusionar, compartir piezas o mantenerlas separadas.
  - «Dividir pago grupal escaneando un recibo» / «Elegir: dividir una boleta sin crear grupo (maquetas)»: Jürgen eligió la opción 1A y su construcción va en 2.3 en paralelo. Las deudas directas deben poder recibir lo que salga de una boleta dividida sin grupo (p. ej. «X me debe su parte»). Mira `docs/propuestas/dividir-boleta-sin-grupo/` si ya existe.
- Para orientarte en el código (lee solo lo necesario, no el repo entero): Grupos en `Yala/App/Views/Groups/` y sus servicios (`GroupService`, miembros solo con nombre con `addMember(displayName:)`, invitaciones, liquidaciones), el modo nube obligatorio (cuentas en Supabase, sincronización, CloudKit) y el modo «solo grupos». Roadmap en `docs/ROADMAP.md` (2.3, «Grupos como gancho de llegada»). Busca ADR relevantes en el índice de `DECISIONS.md`.

## Qué se pide
1. **Experiencia 1 a 1 estilo Splitwise:** registrar rápido «me debe X / 2 esta persona» o «le debo», gastos 1 a 1 sin crear grupo, ver el saldo acumulado con cada persona, recordar y liquidar (total o parcial).
2. **Identidad y enlace por correo**, aprovechando el modo nube obligatorio: cómo se invita o vincula por correo, enlace automático cuando la otra persona ya usa ese correo en Yala, qué pasa si acepta, si rechaza o si nunca contesta.
3. **Personas sin cuenta Yala:** poder empezar a llevar la deuda solo con nombre (o con correo pendiente) sin frenar al usuario, y luego «reclamar/vincular» cuando la otra persona cree su cuenta, sin duplicar ni perder historial.
4. **Modelo técnico y UX:** comparar modelarlo como un grupo 1:1 oculto/especial bajo el capó vs. una entidad propia; dónde vive en la navegación (p. ej. sección o pestaña «Personas» junto a «Grupos»), cómo convive con «solo grupos», con los grupos existentes (saldo total con una persona sumando grupos + directo) y con «Dividir boleta sin grupo».
5. **Privacidad y seguridad:** qué ve cada persona al vincularse por correo, consentimiento/aceptación, qué pasa con los datos si no acepta, y cómo se evita que alguien «cargue» deudas falsas a un correo ajeno.
6. **2 o 3 opciones comparables** (flujo, pantallas, modelo de vinculación por correo vs. sin cuenta), cada una con pros y contras en una línea, **recomendación clara** arriba del todo y estimación de esfuerzo para 2.3 (qué cabe en 2.3 y qué dejar para 2.4).
7. Maquetas en tamaño iPhone 14, claro y oscuro, con ejemplos reales (amigo que te debe un almuerzo a medias; hermano con varios gastos 1 a 1 y un pago parcial; persona sin Yala que luego se registra).

## Entregable
- Entrega final: artifact visual de Claude que facilite decidir; no Markdown, PDF ni documento de puro texto. Navegable, con las opciones comparables lado a lado y los flujos de vinculación por correo.
- En `docs/propuestas/deudas-directas-con-personas/`: las maquetas (HTML o imágenes) y una nota corta con el link al artifact, la recomendación y lo medido en el código. Crea el ticket por archivo declarado en `toca:`.
- Al final, una card «Espera decisión» de Yala 2.3 asignada a `jurgen` (`tablero crear --proyecto Yala --version 2.3 --asignado jurgen --estado "espera decisión" --cierre propuesta-visual --agente frank`), con `--pregunta` con las opciones en una línea cada una, la recomendación y el link del artifact. En la card «Grupos: deudas directas con personas fuera de grupos (2.3)», deja una nota con el link del artifact (no la cierres).

## Qué NO hay que tocar
- Nada de código de la app, pruebas, proyecto de Xcode, esquemas de Supabase ni textos de la app. Solo la carpeta de docs y su ticket declarados en `toca:`.
- No instales nada en el iPhone 14. Si quieres capturas reales como base, puedes mirarlo por DeviceMCP sin tocarlo (Jürgen puede estar usándolo), o en la Max usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los simuladores que enciendas.

## Reglas de la sesión
- Antes de diseñar, mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración (no copies marcas ni pantallas). Puedes mirar cómo lo resuelven Splitwise o Tricount solo como referencia.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash. Ninguna espera de más de 3 min sin escribir avance.
- PR solo de docs a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact. `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen.
- Español neutro latinoamericano en todo lo que lea Jürgen.
