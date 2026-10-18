# Implementar lo ya decidido de la Auditoría UX 2.2 · lotes 12 y 13 (Grupos: entrar, crear, invitar; gastos y saldar)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Qué implementar
Las cards de Yala versión 2.2 en **backlog** cuyo título empieza por «UI/UX 2.2 · L12-» o «L13-» (y el «Bug 2.2 · Otras pantallas de Grupos…») (y los «Bug 2.2» de esos mismos lotes): `tablero listar --proyecto yala --version 2.2 --estado backlog --json` y filtra. Implementa todas: con la decisión de Jürgen si está escrita en la card (contexto, nota o siguiente paso), y si no, con la opción recomendada (ver abajo).
- Fuente de cada decisión: la card, el informe del lote en ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-*/informe.md, el HTML ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html y los «Criterios UX/UI permanentes de Jürgen» del brief madre ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md (léelos: sin degradados, etc.).
- Mueve cada card a in progress al empezar y a done al cerrar (`--agente frank`). Textos nuevos en los 16 idiomas.
- AUTONOMÍA FIN DE SEMANA (Jürgen 16-oct 22:25): Jürgen ya respondió las dudas de estos lotes y no estará en el escritorio. Si al implementar sale una duda (o una card del lote sin decisión explícita), elige TÚ la opción recomendada del informe/HTML (o la que mejor cumpla los Criterios UX/UI permanentes), impleméntala y anótala en la card («Decidido por la sesión: opción recomendada X, porque…») y en el informe. No dejes nada en espera decisión salvo que sea irreversible (borrar datos, esquema de iCloud, cobros): eso sí queda para Jürgen.
- Prueba según /barrido-qa en el simulador. Antes y después en capturas para el cierre.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- 1 simulador a la vez; apágalo y borra tu DerivedData al terminar. Mira `df -h /` antes de compilar.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `clinicas-dentales-bi--*`.
- Todo ticket nuevo lleva su card.
- Cierra con /cerrar-total.

## Paso 0

Medido el 2026-10-18 05:10 (Lima), base `origin/2.2` (`18a17ce0e`).

**Alcance.** Las cards de 2.2 en backlog con «L12-»/«L13-» son seis, todas UI y todas con la decisión de Jürgen
escrita (15-oct): L12-2 (C, botón morado), L12-10 (B, botón morado), L12-13 (C), L13-1 (D combinada: cuadro de la
V2 + deudas con avatares de la V3, sin barras), L13-2 (C), L13-3 (B). El «Bug 2.2 · Otras pantallas de Grupos…» ya
está en done. Las 29 «UX 2.2 · L12/L13» están en *espera decisión* asignadas a Jürgen, sin respuesta escrita: no
entran (el filtro del encargo es backlog). Ninguna decisión es irreversible: ni datos, ni esquema, ni cobros.

**Decisiones asumidas (la sesión, por los Criterios UX/UI y el informe):**
1. L12-2 · Los cinco estados vacíos usan la misma tarjeta: los tres con camino de alta (cómo funcionan, crear
   cuenta, aceptar) marcan su paso de tres; «Sin grupos» con todo hecho marca el 3; «Tus grupos están en tu cuenta»
   y «Sin grupos» con el canal apagado o solo archivados usan la tarjeta sin pasos (no es un primer grupo).
2. L12-10 · La hoja «está listo» sale al cerrarse el formulario (encadenada por su `onDismiss`); el aviso de
   notificaciones de grupo espera a que se cierre, igual que espera al formulario de gasto.
3. L12-10/L12-13 · El enlace se acuña al tocar, no al abrir la hoja (no crear invitaciones que nadie manda). Un solo
   sitio acuña el enlace para los dos.
4. L13-1 · «Saldar» solo en las deudas tuyas (debes o te deben). Las de otros, sin botón: no hay miembros sin app
   (`GroupService.addMember` no tiene llamadores), así que cada deudor o acreedor puede apuntarlo él. Con varias
   monedas en un par, «Saldar» abre un menú por moneda. Desaparece la lista de saldo por miembro (la V3 la sustituía
   por barras y Jürgen quitó las barras).
5. L13-2 · La tarjeta de «¿Lo recibiste?» sale solo al que recibe; «No me llegó» pregunta antes de quitarlo (alerta,
   que pinta las dos salidas). Los pendientes de otros quedan en la lista con «Falta que X lo confirme», sin botones.
6. L13-3 · Dos filas: qué te deben (quién y cuánto) y qué pasó en tus finanzas, según el caso real del puente
   (pagaste con el puente → «−S/ 150 en Cuenta»; puente apagado y «Sí» → espera en la Bandeja; pagó otro o puente
   apagado sin «Sí» → tu parte como gasto de grupo; solo grupos → sin fila). La fila de cuenta sale de la tabla.
7. Vocabulario: «Saldar» en los botones nuevos, como en la variante elegida y la recomendación de L13-5 (sin tocar
   «Liquidar» en el resto, que es de L13-5).
