# Implementar lo ya decidido de la Auditoría UX 2.2 · lotes 3 y 4 (Panel; voz, foto y bandeja)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Qué implementar
Las cards de Yala versión 2.2 en **backlog** cuyo título empieza por «UI 2.2 · L3-», «UX 2.2 · L3-», «UI 2.2 · L4-» o «UX 2.2 · L4-» (y los «Bug 2.2» de esos mismos lotes): `tablero listar --proyecto yala --version 2.2 --estado backlog --json` y filtra. Implementa todas: con la decisión de Jürgen si está escrita en la card (contexto, nota o siguiente paso), y si no, con la opción recomendada (ver abajo).
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

Medido al arrancar (2026-10-17): 29 cards en backlog con esos prefijos (L3-1…L3-17, L4-2/3/4/6/7/8/9/10/11/12/14/15). L4-1, L4-5 y L4-13 no están en backlog (L4-5 en `in qa`); no se tocan. Ningún «Bug 2.2» de estos lotes en backlog. Rama rehecha sobre `origin/2.2` (944f6c94a), `git log origin/2.2..HEAD` vacío. Disco: 21 GB libres.

Decisión por card (de la card; «sesión» = decidido aquí con la recomendada del informe):

| Card | Decisión | Fuente |
|---|---|---|
| L3-1 | Variante 2: rótulo «Balance de <mes>» (otros períodos: «Balance del período») + línea «Entró X − salió Y»; sin movimientos, «Aún no registras movimientos · Tienes X en tus cuentas». Fuera la línea «Tienes X en N cuentas» de «Tus finanzas» | Jürgen |
| L3-2 | B: «Ver detalle ›» junto al rótulo + el mismo nombre («Balance») en Estadísticas | Jürgen |
| L3-3 | B: píldora elegida rellena, chip «Solo gastos ✕» bajo el hero, y la cifra pasa a «Gastado»/«Ingresado» mientras el filtro está puesto | Jürgen |
| L3-4 | A: «Personalizado» deja cualquier fecha hasta hoy | Jürgen |
| L3-5 | A: «Mostrar solo lo que elijas / Ocultar lo que elijas», «(Todas)», fuera la nota de monto y la fila de etiquetas sin etiquetas | Jürgen |
| L3-6 | B: una línea por sección + mismo nombre («Tus finanzas») | Jürgen |
| L3-7 | B: el «?» solo explica (el tamaño sale de la hoja) + la explicación con sus números donde haya dato | Jürgen |
| L3-8 | A: un aviso a la vez con «1 de N» | Jürgen |
| L3-9 | Variante 3: plegada con flecha, cuentas en chips (nombre y saldo) y «Agregar» al final; sin la línea «tienes X en N cuentas» | Jürgen |
| L3-10 | Variante 2: botón rosa relleno «Crea tu primera cuenta» + «Toca aquí y te ayudamos: es un paso» en lugar de la fila apagada | Jürgen |
| L3-11 | B: título con el nombre, línea «Saldo al inicio + entró − salió = saldo», valores en la gráfica y «Filtrar» arriba | Jürgen |
| L3-12 | B: filas que abren el registro + un solo título | Jürgen |
| L3-13 | A: sin favoritos, los dos presupuestos más usados; Salud dice «empieza a contar el mes que viene» + «Ver mis presupuestos» | Jürgen |
| L3-14 | B: tres partes con su peso + qué mejorar, anillo sólido sin degradado | Jürgen |
| L3-15 | B: la suma visible, dos frases, un solo título | Jürgen |
| L3-16 | Variante 2: relleno sólido del color de la cuenta + «Filtrando» | Jürgen |
| L3-17 | B: saldo sin «+», línea discontinua con nombre, y los solapes del eje | Jürgen |
| L4-2 | A: aviso en lenguaje de usuario, botón principal relleno, «Privacidad» como enlace | Jürgen |
| L4-3 | A: «Apuntarlo a mano» en micro denegado, foto sin importe y archivo ilegible | Jürgen |
| L4-4 | A: «Guardar/Guardado» y «registro» en todo el lote | Jürgen |
| L4-6 | A: deslizar del todo descarta (Archivados); Eliminar, segunda acción | Jürgen |
| L4-7 | B: «Guardar los N listos» sobre la lista + «1 sigue pendiente: …» al final | Jürgen |
| L4-8 | B: frase fija bajo el título + etiqueta de origen por fila | Jürgen |
| L4-9 | A: «Lo descartaste el …» + «Volver a pendientes» en el editor | Jürgen |
| L4-10 | A: la extensión acepta un PDF | Jürgen |
| L4-11 | B: línea en la hoja del iPad + marco «Suelta para leer el recibo» | Jürgen |
| L4-12 | B: ejemplo + precio/prueba en la puerta Pro de voz y foto, estrella sin halo | Jürgen |
| L4-14 | A + unificar los tonos de importe con los del Panel en todas las pantallas | Jürgen |
| L4-15 | A: ayuda de qué contraseña + el error se va al escribir | Jürgen |

Asumido por la sesión (sin pregunta, autonomía de fin de semana):
- L4-4 con L4-6/L4-9: «Rechazar» pasa a «Descartar» en la Bandeja (es el verbo de L4-5, ya en QA). El estado interno `rejected` no cambia: sin migración.
- Orden de trabajo: Panel (L3) y luego Bandeja/voz/foto (L4). Un PR contra 2.2 con un commit por bloque.
- Review adversarial: acotada, una lente con refutación sobre lo que sí es cifra nueva (la cuenta del saldo de la ficha de cuenta, el balance con signo del hero, presupuestos sin favoritos, pesos de Salud). El resto es copy, UI y navegación. L3-14 y L3-15 enseñan cálculos existentes sin cambiarlos.

## Resultado

- 29 cards implementadas en un PR contra `2.2` (dos commits: Panel / voz, foto y Bandeja). Textos nuevos y cambiados en los 16 idiomas.
- Desvíos medidos respecto a la tabla: L3-3 dice «Gastos de octubre» / «Ingresos de octubre» en vez de «Gastado» / «Ingresado» (el rótulo ya nombra el mes; «Gastado» suelto no lo hacía). L3-17: la línea discontinua es el PROMEDIO del período, no el saldo al empezar; se llama «Promedio». L4-2 sigue siendo una alerta del sistema (no admite relleno ni enlace pequeño).
- Encontrado al probar en el simulador y arreglado: «Lo descartaste el 17 oct.. Está…» (doble punto: la fecha va con el mes entero); el «?» de Últimos registros quedaba suelto en el centro de la tarjeta; el mes salía con mayúscula («Balance de Octubre»); la IA caída (`serviceUnavailable`) en voz y foto solo ofrecía «Cerrar» y ahora ofrece también «Apuntarlo a mano».
- Device-QA en el iPhone: compartir un PDF, soltar un recibo en el iPad, deslizar + Deshacer en la Bandeja, dos avisos a la vez en el Panel (apagados en modo test), y la línea de precio de la puerta Pro (sin productos de StoreKit en el simulador no sale).

