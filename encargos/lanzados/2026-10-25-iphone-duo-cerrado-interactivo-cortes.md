---
cierre: cierras-tu
---
# iPhone Duo · sesión interactiva (cortes / área segura)

## Qué hay que hacer
Sesión INTERACTIVA con Jürgen: NO cierres solo. NO uses /cerrar-total. Jürgen conduce y cierra.

Revisar iPhone Duo **cerrado** vista por vista (y si Jürgen quiere, también abierto). En cada vista: captura, pregúntale si hay algo que no le gusta, ajusta según su feedback, vuelve a capturar. Foco principal: la sensación de que elementos se «cortan» o la barra vertical parece una pieza aparte, aunque se respete el área segura de Apple.

## Contexto
- Ya se aplicó opción 2 de barra (preferir acciones) y regla A de ancho seguro (PR #624).
- Jürgen está de acuerdo con respetar el área segura, pero NO le gusta la sensación de corte / barra como pieza separada (se ve feo).
- Referencias que él pegó (Welcome y Panel con A aplicada): `~/Claude/tmp-frank/duo-cortes-interactivo-2026-10-25/welcome-cortado.png` y `panel-cortado.png`.
- Skills Apple a consultar: `app-resizability`, `swiftui-whats-new-27` (y lo que aplique a safe area / liquid glass / barra vertical Duo).
- Abierto H/V/P: solo si él lo pide; por defecto foco en cerrado.
- Card de decisión A/B previa (ancho): esta sesión la sustituye en la práctica; no fijes B a ciegas. Itera con él.

## Cómo trabajar
1. Sim Duo cerrado (1 sim a la vez; pipeline serial Yala).
2. Orden sugerido de vistas: Welcome → Panel → Estadísticas → Presupuestos → resto de pestañas/pantallas relevantes cerradas.
3. Por cada vista: captura → pregunta concreta («¿algo que no te guste en esta?») → aplica ajustes → nueva captura → confirma antes de pasar a la siguiente.
4. Prioriza soluciones que respeten safe area PERO eliminen el look «cortado» (márgenes, glass, cómo convive el contenido con la barra vertical, etc.).
5. Commits/PR solo cuando Jürgen lo pida o al cerrar él la sesión.

## Qué NO hay que tocar
- No /cerrar-total.
- No inventar preferencias sin preguntarle.
- No cambiar iPhone normal salvo que él lo pida.
- No paralelizar sims.
- Marketing/ no tocar.

## Criterio de terminado
Jürgen dice que basta / cierra la sesión. Debe haber capturas del recorrido y cambios acordados con él en el worktree/PR.

## Limpieza
Pipeline serial Yala: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, bootear 1 sim, probar, apagar. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de un worktree vivo.

## Paso 0 — decisiones

Sesión interactiva: las decisiones de producto las toma Jürgen en el chat, vista por vista; aquí se anotan.

1. **Welcome con logo: fuera del ancho seguro** (Jürgen). `WelcomeFlowScreen` (Hero y puertas) ocupa también la
   columna de la barra y se centra en la pantalla entera, solo por el lado de la barra vertical. *El asumido era falso:*
   los selectores usan otro envoltorio (`WelcomeFormScreen`); vio A y B en capturas y los dejó en el ancho seguro.
2. **«‹ Volver» → el botón atrás del sistema** (Jürgen): en el iPhone, el círculo de cristal de toda la app; en el Duo
   cerrado, en la barra vertical.
3. **Carruseles: fundido contra la barra** en vez del tajo (Jürgen eligió la opción 1, luego por carrusel), en todos.
4. **Estadísticas, Planificación, Registros y Grupos:** sin cambios. Los botones flotantes van con la card
   `tablero-consistencia-boton-nuevo-vs-fab-panel-pa-kzhe`.
5. **Ajustes a todo el ancho** (Jürgen eligió A viendo que al desplazar las filas pasan bajo la hora y la X), y el
   doble «‹» de sus pantallas arreglado (lo pidió él).
6. **Card nueva** de estilos del onboarding: prioridad alta, versión 2.2 (Jürgen).
