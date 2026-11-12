# Implementar lo ya decidido de la Auditoría UX 2.2 · lotes 11 y 16 (estadísticas; ajustes, perfil y preferencias)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Qué implementar
Las cards de Yala versión 2.2 en **backlog** cuyo título empieza por «UI/UX 2.2 · L11-» o «L16-» (y el bug de «Últimos 7 días») (y los «Bug 2.2» de esos mismos lotes): `tablero listar --proyecto yala --version 2.2 --estado backlog --json` y filtra. Implementa todas: con la decisión de Jürgen si está escrita en la card (contexto, nota o siguiente paso), y si no, con la opción recomendada (ver abajo).
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

## Card extra sumada (decisión de Jürgen del 17-oct 21:29)
- «El widget de Presupuestos de la pantalla de inicio no mira los favoritos»: opción A. El widget de inicio no sigue los favoritos; cambia el texto de la pantalla de favoritos de Presupuestos para que diga «tarjeta del Panel», en los 16 idiomas. Muévela a in progress al empezar y a done al cerrar con `--agente frank`.
- Textos (decisión de Jürgen 17-oct): en ningún texto de la app (Ajustes, Datos personales, avisos y pistas de IA, en los 16 idiomas) se escribe «OpenAI»; se dice «un servicio de IA» con enlace a la política de privacidad, que es el único sitio que nombra al proveedor.

## Paso 0

Medido al arrancar (2026-10-18, rama sobre `origin/2.2` en `2776b307e`).

**Alcance: 11 cards.** L11-1, L11-2, L11-3, L11-4, L11-11, «Últimos 7 días», L16-3, L16-9, L16-12, «Bug lote 16 · cambio
de divisa a medias» y el widget de favoritos de Presupuestos. Los dos «Bug 2.2» que salen en el backlog (plurales
regionales y «Ocultar» con una moneda) son del lote 8, no de 11 ni 16: fuera. Las cards de L11/L16 en «espera decisión»
no entran (el encargo pide las de backlog).

**«OpenAI» en los textos: ya hecho.** PR #541 (en 2.2) lo quitó de los 16 idiomas y de los Info.plist, con el test
`AIConsentProviderNameTests.noVisibleString_namesTheAIProvider`. Medido: 0 apariciones en `Yala/Resources`. No se toca.

Decisiones que el encargo no toma, tomadas por la sesión (opción recomendada o la que mejor cumple los criterios):

1. **«Últimos 7 días» = hoy y los 6 anteriores**; «Últimos 30 días» = hoy y los 29 anteriores. Es lo que dice el
   nombre y lo que hacen las apps de banca. Mismo cambio en el widget (`WidgetDataService`), el período del chat de IA
   (`last_7_days`) y el informe semanal, que pasa a contar los mismos 7 días que la pantalla que abre (L11-2). El cierre
   en la medianoche de mañana es común a todos los períodos en curso y no se toca.
2. **L11-2 · el período del aviso deja de valer** al salir de Estadísticas **o** si la persona elige otro período
   durante la visita (desde ese momento el período es suyo).
3. **L11-3 · flechas:** el anterior de «Este mes» es «Mes pasado» y el de éste, el mes de antes como rango; el
   siguiente vuelve igual. Semana, 7 días, 30 días, año y rango propio pasan por bloques del mismo tamaño. «Todo el
   tiempo» no lleva flechas. La flecha de «siguiente» se apaga si llevaría al futuro.
4. **L11-4 · la frase sale en las tres pestañas** donde estaba el «P-1 / A-1» (Resumen › Tus cifras, Tendencias ›
   Comparativa, Distribución › Análisis del gasto), con el tramo exacto que se compara.
5. **L16-3 · el texto de la hoja usa el código de la divisa** («Cambiar a EUR», «Lo que apuntaste en PEN sigue en
   PEN»): el plural del nombre de cada divisa en 16 idiomas no existe en el sistema y se escribiría mal. La pantalla ya
   dice «moneda principal» en todas partes (lo unificó el PR #509): el texto nuevo usa ese término.
6. **Bug del cambio de divisa:** si falla, se restauran los valores de cada registro (sin `rollback()`, que tiraría
   cambios ajenos pendientes), la divisa sigue entre las secundarias y sale un aviso. La barra llega al 100 %.
7. **L16-9:** el mismo relleno en Temas, Icono de la app, las hojas de Personalización y la hoja de divisa preferida
   (es una hoja de selección de Ajustes y quedaría distinta).
8. **L16-12:** aro dorado sólido en la cabecera **y** en el avatar de la barra (es el mismo aro); insignia «Yala Pro»
   dorada con texto oscuro; fuera el tinte dorado de la cabecera. El chip «PRO» pequeño pasa también a dorado sólido.
   El dorado del botón de Yala IA y de las acciones rápidas no se toca: es L14-5, en espera de decisión.
9. **Favoritos de Presupuestos:** cambian los tres textos de esa pantalla (aviso, título de la vista previa y vacío).
10. **Tras la review adversarial (2026-10-18):** la frase de comparación de Tendencias y Distribución usa el último día
    con datos (como su cálculo); Resumen, hoy. Elegir el período en Ajustes o en el Panel también cierra la visita del
    informe. Las flechas recuerdan con qué paso llegaron a un rango (un domingo, «los 7 días anteriores» son además una
    semana entera y volvían como «Esta semana»).
