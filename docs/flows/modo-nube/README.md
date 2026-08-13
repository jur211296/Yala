# Atlas de Flujos · Modo Nube

Herramienta de la **revisión integral de los flujos de Modo Nube**. Desde el chip **F4** es un
**storyboard**: una pestaña por recorrido y, dentro, la secuencia de pantallas como **frames grandes
visibles sin un solo clic** — la captura real a tamaño legible, el **copy exacto con su key de l10n**
(seleccionable), qué queda persistido, cómo se sale y la coordenada de código. Cada recorrido tiene además
una vista **Mapa** con todas las ramas (layout calculado con ELK, no dibujado a mano).

**Se abre con doble clic en `index.html`.** Funciona offline: no hay ni una URL remota.

    open docs/flows/modo-nube/index.html

Deep-link para citar un nodo en un ticket: `index.html?node=<id>` (salta a su frame y lo resalta).
Cada frame tiene un botón **«⧉ referencia»** que copia al portapapeles una plantilla de ticket con el id,
el recorrido, las keys de l10n visibles y la coordenada.

## El eje: PERSONA, no mecanismo (F6 · 2026-08-12)

**Hasta F5 el Atlas estaba indexado por MECANISMO**: siete flujos que eran las siete máquinas del código
(alta, re-entrada, migración, reversa, sign-out, puertas de Grupos, degradados). Servía para auditar el
código y era inútil para la pregunta que de verdad se hace uno mirándolo: *«soy esta persona, tengo este
móvil, toco este botón — ¿qué veo?»*. Cada recorrido humano cruzaba tres o cuatro flujos y **ninguno se
contaba de principio a fin**.

F6 cambia el eje a **once recorridos por persona**. Con dos decisiones del owner:

1. **Los errores viven DENTRO del recorrido donde te los encuentras.** No hay pestaña «degradados»: sus
   ocho paneles se repartieron entre las personas que se topan con ellos, y varios aparecen en más de una.
2. **Los ids de los paneles NO se renombran.** `alta-hero` vive en siete recorridos y sigue llamándose
   `alta-hero`: el id es el **nombre propio** del panel, no su clasificación. Así las 35 imágenes de
   `img/` siguen valiendo y los deep-links citados en tickets viejos siguen resolviendo. **El reparto vive
   en `data/storyboard.js`, y solo ahí.**

| # | Recorrido | Paneles |
|---|---|---|
| R1 | Empiezo de cero · cuenta privada | 11 |
| R2 | Empiezo de cero · cuenta en la nube | 26 |
| R3 | **Llego con una invitación a un grupo** | 37 |
| R4 | Solo quiero grupos · creo el primero | 29 |
| R5 | Vuelvo a Yala en un móvil nuevo | 45 |
| R6 | Soy privada y salgo de Yala | 19 |
| R7 | Soy de la nube y cierro sesión | 11 |
| R8 | Paso de privada a la nube | 17 |
| R9 | Vuelvo de la nube a privada | 9 |
| R10 | Estoy de visita en el móvil de otra persona | 24 |
| R11 | El dueño recupera su móvil | 21 |

## Anclaje

Todo lo que hay aquí se midió contra **HEAD `5bbb5690`** (branch `2.0.5`) el **2026-08-12**. El anclaje
está visible en la cabecera del propio Atlas — si el código se mueve, lo que caduca es el Atlas, y su
fecha lo dice.

**F6 añadió 72 paneles (82 → 154).** No son una reorganización: son los recorridos que el eje por
mecanismo no contaba. El mayor con diferencia era la **invitación a un grupo**, que no tenía **un solo
panel** pese a que `InviteRecoveryView.swift` es una pantalla real y detrás de ella hay un subsistema
entero (`InviteLinkService`, `GroupBackendInviteService`, `PendingJoinStore`, `GroupJoinReconciler`).
`.inviteRecovery` aparecía en veinte paneles **como flecha de salida** y en ninguno como destino.

Los 72 se derivaron del código en cinco pasadas independientes, y **cada una pasó por un refutador
adversarial** que re-midió coordenada a coordenada y key a key. De los 72, **solo 15 sobrevivieron
intactos**: la refutación encontró 100 problemas —11 coordenadas desplazadas solo en R3, y un panel cuya
tesis central era falsa— y una segunda pasada los corrigió y volvió a sellar (553 coordenadas re-abiertas
una a una, 9 problemas residuales, todos aplicados a mano).

> **Lo que este chip enseñó, y conviene leer antes de fiarse del verde.** La tesis «el status `rejected` ni
> siquiera existe server-side» era **falsa** —`remove_member` lo escribe, `ddl:596`— y la conclusión de
> usuario que colgaba de ella («el rechazo no tiene pantalla») resultó **cierta por otra causa**: la de
> LECTURA, no la de existencia. Una conclusión correcta apoyada en la medición equivocada es exactamente
> como envejece mal un documento. Está anotado dentro del panel `r3-aprobacion`.

## La regla madre

> El contenido se deriva de las **tablas de la lógica pura** y de lo que la app hace de verdad —
> **jamás de `MODO-NUBE-ARQUITECTURA`**. Donde el diseño y el código difieren, gana el código y la
> divergencia se **anota** en el frame del nodo con ⚠︎.

Un Atlas derivado del diseño sería el mismo drift documental que esta épica lleva un mes pagando, en
bonito. Por eso la sección **Cobertura** existe: dice, tabla por tabla, cuántas celdas tiene y cuántas se
dibujaron. Un desajuste es un hueco **dicho**, no silencioso.

## Qué hay en la carpeta

| Ruta | Qué es |
|---|---|
| `index.html` | El Atlas: pestañas por recorrido, storyboard + mapa, cobertura, hallazgos, guion device |
| `lib/graph.js` | Parser de los grafos + medición de texto + geometría — **compartido** entre la página y `check.mjs`, para que el pin de solapes mida exactamente lo que se pinta |
| `data/nodes.js` | El CONTENIDO de los paneles (154 nodos con sus coordenadas de código) |
| `data/flows.js` | Los 11 grafos (sintaxis mermaid, SSOT de la estructura) + la auto-auditoría + los hallazgos |
| `data/storyboard.js` | **El reparto**: qué paneles ve cada persona y en qué orden. Un panel puede vivir en varios recorridos |
| `data/l10n.js` | Las keys de l10n del copy visible de cada pantalla, con su valor exacto de `es.lproj` |
| `data/f2.js` | El estado de las capturas: `device-only` con motivos, los `pending`, las `stale` y los hallazgos F2 |
| `vendor/elk.bundled.js` | elkjs 0.11.0 vendorizado — **1,6 MB**, la única dependencia |
| `img/` | Las capturas reales del simulador (35) |
| `check.mjs` | El pin — ver abajo. Corre **sin dependencias** (`node check.mjs` y listo) |

## Cómo se verifica

    node docs/flows/modo-nube/check.mjs

Once bloques: los 11 grafos **parsean** con el parser real (una línea desconocida es error duro) · cada
`click … showNode("x")` resuelve · ningún panel **huérfano** · `id` de screenshot únicos y con convención ·
panel completo con coordenada · **offline** · contrato F2 (cero nodos vacíos) · **SOLAPES**: el layout de
cada recorrido, medido con las cajas visuales que la página pinta, no produce ninguna intersección · **L10N**:
toda key citada existe en `es.lproj` y su **valor coincide** · **STORYBOARD** · y el **conteo esperado**
(154 paneles · 111 shots · 35 imágenes · 76 device-only · 113 entradas l10n).

**El bloque STORYBOARD cambió con el eje.** Antes derivaba el flujo «casa» de un panel del **prefijo de su
id** (`k.split("-")[0]`), que funcionaba solo porque los siete flujos y los siete prefijos eran la misma
cosa. Ahora exige algo que no depende del nombre y es más fuerte: **todo panel con pantalla aparece en al
menos un recorrido**.

**Muerde** (mutaciones verificadas el 2026-08-12, cada una a exit 1):

| Mutación | Resultado |
|---|---|
| Quitar un frame del storyboard | `r3-esperando tiene pantalla y NO aparece en NINGÚN recorrido` |
| Apuntar un frame a un panel inexistente | `frame "r3-banner-que-no-existe" no existe en nodes.js` |
| Borrar un track entero | `visita-cuenta-nueva tiene pantalla y NO aparece en NINGÚN recorrido` |
| Inventar una key de l10n | `la key "storage.titulo.inventado" NO existe en es.lproj` |
| Añadir un panel sin declararlo | `orphan` + `panels: esperado 154, medido 155` |

> Un primer intento de la primera mutación **no llegó a mutar el fichero** (el id iba al final de la lista,
> sin coma, y el `perl` no casó) y el pin dio verde. Queda escrito porque es el modo de fallo de esta
> familia: **una mutación que no muta prueba exactamente nada**, y se lee igual que un pin que muerde.
> Desde F6 el guion comprueba con `diff` que el fichero cambió antes de correr el pin.

**Lo que el pin NO puede ver:** una pantalla que nadie añadió (detecta una key mal citada, no un nodo
ausente), una coordenada `Fichero.swift:línea` que se desplazó —cita el fichero, no la línea— y una
captura que sigue existiendo pero ya no retrata lo que la app pinta. Las tres mordieron en F5 y las tres
se resolvieron a mano.

## Estado de las capturas — el hueco más grande del Atlas hoy

**35 imágenes para 111 paneles con pantalla.** Los 72 paneles de F6 nacen **sin captura**, y está
declarado en `data/f2.js` en vez de escondido:

| Categoría | Cuántos | Qué significa |
|---|---|---|
| Capturadas | 35 | imagen real en `img/` |
| `pending: true` | **39** | el simulador SÍ puede producir el estado y esta pasada no lo abrió — **es el guion de la próxima pasada de captura** |
| `device-only` | 37 | el sim NO puede: exige sesión backend real, multi-device o una respuesta de servidor no fabricable |
| `stale` | 0 | el mecanismo se conserva: vuelve en cuanto una pantalla se re-escriba |

La pestaña **«Capturas · guion device»** los ordena por recorrido. Y hay dos límites duros que conviene
saber antes de planificar esa pasada: **la sesión secundaria está al 0 % en producción** (R10 y R11
completos exigen dos cuentas reales) y **App Attest rechaza un build de desarrollo contra producción**
(ver `.claude/rules/gateway-attest.md`), así que un build de Xcode sirve para diagnosticar, no para validar.

> ⚠️ **Dos trampas del simulador, para el yo-futuro.** (1) El scheme «Yala Dev» compila con **`Debug-Dev`**,
> no con `Debug`: con `Debug` sale el bundle de producción, sin `DEV_BUILD` y con los percents apagados, así
> que ni el sub-chooser de nube ni el canal de Grupos aparecen. (2) En un build Dev, **una instalación
> limpia no nace virgen en preferencias**: a los 12 s de un launch sin tocar nada ya hay `onboardingMode`,
> `userName` y `defaultCurrencyCode` escritas. No se identificó al escritor ⇒ la invariante «nada se
> persiste hasta que la cadena confirma» **no se puede verificar en Dev leyendo el plist**.

## Los hallazgos van al vault, no aquí

La derivación de F6 destapó **24 hallazgos medidos** que no son documentación: son bugs. Viven en
`$VAULT/Bugs/`, indexados en **`_hallazgos-atlas-eje-persona-2026-08-12.md`**, con el nivel de verificación
de cada afirmación (re-verificado a mano · doble pasada · inferido) y si muerden hoy o están detrás de un
flag apagado. El Atlas los referencia desde los paneles con ⚠︎; el trabajo de arreglarlos es otra sesión.

El más grave: **la visita en el móvil de otra persona escribe en el iCloud y las preferencias del dueño
por seis vías sin guard**, y el source-scan que debía cubrirlo mira el inventario equivocado.
