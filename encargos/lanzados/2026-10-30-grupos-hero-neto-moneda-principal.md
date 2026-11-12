---
esfuerzo: high
release: no
---
# Grupos (Yala completo): «tú debes» más grande en color de texto normal y chip glass a lo ancho con el neto en tu moneda principal

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `grupos-hero-neto-moneda-principal` · Sesión cola **S29b** · al cerrar → **S29c** (`duo-perfil-en-barra-lateral`).

## Contexto
Jürgen (2026-10-30): en el hero de la vista Grupos, solo para Yala completo (el único plan que elige moneda principal en Personalización).

Card:
- `tablero ver tablero-grupos-yala-completo-tu-debes-mas-grande-apil`

## Qué se pide
1. El monto de «Tú debes…» un poco más grande y en el color de texto normal del tema, igual de importante que «En tus grupos te deben». Los montos ya no van en teal.
2. Debajo de ambos, un chip glass informativo **a lo ancho** (todo el ancho del hero, no centrado y chiquito) con el neto convertido a la moneda principal y su símbolo. Por ejemplo: «En tu moneda principal (S/), esto significa un saldo de S/ 50 que te deben» o «…que debes», según el signo del neto. Usa los tipos de cambio de la app. Si el neto es 0, texto neutro.
3. En Yala gratis o sin moneda principal el chip no aparece y el hero queda como hoy, salvo el punto 1 si aplica al plan completo.
4. Lógica del neto y del texto aislada y con tests (signo, 0, una y varias monedas), con strings en los 7 idiomas.
5. Capturas en simulador, claro y oscuro (Yala completo con una y con varias monedas, y Yala gratis), en `capturas/`.
Al abrir el PR, pasa la card a «in qa» de Jürgen: puede querer retoques, por eso va primera.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

## Bug extra en la misma pantalla: parpadeo con espacio vacío sobre el hero (Jürgen 2026-10-30)

Video: `~/Claude/tmp-frank/video-grupos-parpadeo-hero-2026-10-30.mp4`. Al entrar a la pestaña Grupos desde Panel, durante ~1–2 s aparece un espacio vacío (del alto del bloque del hero, ~15–20 % de la pantalla) entre el título grande «Grupos» y el hero «En tus grupos te deben». Luego el espacio colapsa de golpe y todo el contenido (hero, botones «Nuevo gasto»/«Nuevo grupo», lista) salta hacia arriba, sin animación. No aparece ni desaparece ningún banner o chip. Encuentra la causa (p. ej. una vista que reserva alto mientras carga, un banner/espaciador condicional, safe area o el título grande del NavigationStack), arréglala en la raíz para que el hero quede en su sitio desde el primer frame, y verifica en simulador con grabación o capturas al entrar a Grupos. Agrega un test o chequeo si se puede. Hazlo antes de lo del chip, para que el chip nuevo no herede el salto.

## Rediseño de Grupos: primero propuestas (Jürgen 2026-10-30, ~17:06 Lima)

Jürgen da permiso para rediseñar la vista Grupos (hero + filas de grupo). Referencias que mostró: 2.1 (montos invertidos, ya corregido en 2.2), 2.2 actual y Splitwise. Acuerdos:
1. Montos con color semántico: verde para «te deben», rojo o naranja rojizo para «debes». Deben verse bien en TODOS los temas (claro/oscuro y cada tema con degradado); usa los tokens de color del tema, no hex sueltos. «Debes» con el mismo peso visual que «te deben».
2. Filas de grupo con nombre de la persona: «Debes a Maria P. S/ 8,314.38» / «Maria P. te debe $1,884.89», cada una con su color. Máximo 3 filas de personas por grupo; si hay más, una última «y N más».
3. Chip glass a lo ancho con el neto en moneda principal (solo Yala completo), como titular claro de si vas a favor o en contra.
4. Orden: primero lo que debes, luego lo que te deben, igual en hero y filas.
5. Arreglar antes el parpadeo del hero (sección de arriba).

Proceso (Jürgen 2026-10-30 ~17:07): esta sesión CIERRA SOLA y NO implementa el rediseño de hero y filas. Arregla el parpadeo del hero (eso sí se implementa, con test o verificación y PR). Para el rediseño, arma 3 propuestas distintas con capturas en simulador (tema oscuro y claro, más un tema con degradado), con datos parecidos a los de Jürgen: dos grupos con deuda en S/ y crédito en USD, y uno con 5 o más personas. Déjalas en un artifact de revisión: `docs/disenos/grupos-rediseno-2-2/` en el repo (las capturas más un README.md con cada propuesta, pros y contras y tu recomendación), incluido en el PR. Crea una card nueva en 2.2, en «awaiting decision», asignada a jurgen, titulada «Grupos: elegir una de las 3 propuestas de rediseño (hero y filas)», con el link a esa carpeta del PR. No dejes la sesión esperando: termina con /cerrar-total. La implementación de la propuesta elegida será otra sesión.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
El resto de la vista Grupos, los cálculos de saldos y los tipos de cambio en sí. Ninguna otra sesión Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Se ve en Yala completo con una y con varias monedas y no aparece en gratis. Hay capturas claro y oscuro, tests verdes del neto y del texto en los 7 idiomas, review adversarial del diff y PR a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo (bypass), Frank, 2026-10-30)

1. **Alcance: el encargo se contradice y manda la sección más reciente (17:07).** Esta sesión implementa SOLO el arreglo del
   parpadeo. El chip del neto, el «debes» más grande y los colores verde/rojo son parte del rediseño (acuerdos 1-4) y se
   enseñan en las 3 propuestas, no se implementan. Implementar ahora el punto 1 original (montos en color de texto, más
   grandes) chocaría con el acuerdo 1 (verde/rojo). Opción conservadora y reversible.
2. **Causa del parpadeo (medida en simulador, iOS 27.0):** `.searchable(placement: .navigationBarDrawer(displayMode:
   .automatic))` en la lista de Grupos. Al volver a la pestaña, la barra reserva el alto del cajón vacío ~0,5 s y lo pliega:
   hero, botones y lista saltan. Es la única página de pestaña con buscador.
3. **Arreglo: `.always`.** El buscador queda siempre visible bajo el título, como en las otras 5 pantallas con buscador. Cambio
   de una línea, reversible. Alternativas descartadas: quitar el buscador (decisión de producto) o moverlo a la barra de
   abajo (cambia la navegación).
4. **Red:** test de cableado por source-scan que prohíbe el cajón `.automatic` en `Yala/App/Views` + vídeo antes/después.
5. **El flotante «+» que asoma ~0,3 s al entrar** (otro parpadeo del mismo vídeo, por `onScrollVisibilityChange` con la
   pestaña oculta) **no se toca**: no lo pidió y es de un componente compartido con el Panel. Va a una card.
6. **Propuestas:** maquetas temporales `#if DEBUG` (`-mockgrupos N`) con datos fijos parecidos a los de Jürgen, capturadas con
   un conductor XCUITest temporal en Claro, Oscuro, Liquid Glass y Rosa (+ Yala gratis). Se retiran antes del gate; al PR van
   solo las capturas y el README en `docs/disenos/grupos-rediseno-2-2/`.
7. **Colores de las maquetas:** verde #15803D/#4ADE80 y rojo anaranjado #C2410C/#FF7A59 (claro/oscuro), propuestos como
   tokens nuevos con test de contraste en la implementación.
8. **Cards:** la del encargo pasa a «in qa» con nota (parpadeo en QA; hero y chip, en la card de decisión). Card nueva en
   «awaiting decision» para elegir propuesta, asignada a jurgen.
