---
esfuerzo: medium
---
# El onboarding sigue los estilos del resto de la app — implementación

Card `tablero-el-onboarding-no-sigue-los-estilos-del-r-i00g`. Versión 2.2. Base `origin/2.2`.
Cierre: cierra sola con `/cerrar-total` salvo decisión vital (fuerza mayor, seguridad o diseño crítico).
Lienzo con las propuestas y capturas: https://claude.ai/artifact/F4QUNid2UUSuN9MRGbCzFA
Detalle medido y decisión: `tickets/backlog/onboarding-sigue-los-estilos-del-resto-de-la-app.md`, secciones «Propuestas (2026-10-26, sesión S4)» y «Decisión de Jürgen (2026-10-26)» (PR #640, docs). Capturas del antes: `~/Claude/worktrees/_capturas/onboarding-estilos/`.

## Contexto
Jürgen siente que el Welcome y el onboarding no usan las fuentes, botones y textos del resto de la app. La sesión de propuestas del 26-oct midió los cuatro ejes y Jürgen eligió sobre el lienzo.

## Decisiones de Jürgen (2026-10-26): D1 A, D2 B, D3 A, D4 A
1. **D1 A, botones:** `WelcomeFormButton` pasa a cápsula y 15 pt medium (la letra de `YalaPrimaryButton`); conserva blanco lleno y contorno.
2. **D2 B, titulares:** levanta la decisión del 15-sep sobre el serif. `DS.Typography.welcomeHeadline` deja de ser serif y los selectores usan el titular sans de la app. Del 15-sep sigue en pie el resto: una tarjeta y ningún botón recomendado. La alineación a la izquierda de los selectores y el titular centrado del onboarding se quedan; si al verlo en el simulador piden igualarse, no lo decidas: anótalo como pregunta en el cierre.
3. **D3 A, listas:** los pasos del onboarding que eligen entre opciones agrupan las filas en una tarjeta con separadores; la marca de elegido se queda.
4. **D4 A, textos (16 idiomas, BRAND-VOICE):** «Empieza desde cero. Te guiamos paso a paso.» · «Viajes, casa compartida, salidas…» · «Tus datos, en tu iCloud.»

## Qué NO hay que tocar
- El fondo índigo→negro fijo (`WelcomeFlowStyle`), el Hero con logo y carrusel, la forma de los selectores.
- marketing/ y Web/ (Lola). No lanzar otras sesiones Yala.

## Cómo se sabe que está bien
Welcome y onboarding en el simulador con capturas del antes y el después (`capturas/antes*.png`, `capturas/despues*.png`) en los pasos tocados; los tres textos traducidos en los 16 idiomas; gate verde; PR a 2.2 en auto-merge; card a in qa asignada a jurgen.

## Pie pipeline
- Una sesión Yala a la vez. Rebase único antes del PR (gate después del CI del PR anterior).
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0 (auto-contestado, 2026-10-27)

- Capturas del «antes» reutilizadas del 26-oct sobre `origin/2.2`: ningún commit posterior toca esas pantallas.
- El paso del saldo inicial no se agrupa: cada opción abre su formulario debajo y la tarjeta rosa ya estaba decidida (L1UI-2).
- pt-BR: además de «república», se neutraliza «rolês» → «passeios».
- Filas agrupadas con margen `md` para que ningún título se parta.
- Alineaciones (selectores a la izquierda, onboarding centrado): no chirrían en el simulador; quedan como pregunta en el cierre.
