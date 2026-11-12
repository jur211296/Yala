# Implementar lo ya decidido de la Auditoría UX 2.2 · lote 14 (Yala IA)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Qué implementar
Las cards de Yala versión 2.2 en **backlog** cuyo título empieza por «UI 2.2 · L14-» o «UX 2.2 · L14-» (y los «Bug 2.2» de esos mismos lotes): `tablero listar --proyecto yala --version 2.2 --estado backlog --json` y filtra. Implementa todas: con la decisión de Jürgen si está escrita en la card (contexto, nota o siguiente paso), y si no, con la opción recomendada (ver abajo).
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

Cards del lote (backlog al arrancar): L14-2 (C), L14-3 (D), L14-4 (D), L14-5 (D), las cuatro con decisión de Jürgen del 15-oct. No hay «Bug 2.2» de L14 abiertos (B1-B3 ya entraron en el PR #507). L14-1 y L14-6…13 siguen en espera de decisión: fuera.

Decidido por la sesión (lo que las cards dejan abierto):
1. **L14-2 · orden.** Primero la presentación, el permiso en su último paso («Antes de empezar»). La alerta del sistema queda solo para quien ya vio la presentación y retiró el permiso en Privacidad, y en la propia pantalla de Privacidad (L14-11 sigue pendiente).
2. **L14-2 · texto.** Las tres filas reparten el texto legal de hoy sin añadir nada: no se nombra a OpenAI ni se promete «no guarda tus conversaciones» (la maqueta lo decía; el texto vigente no). «Tú decides» nombra la pantalla real con sus nombres localizados (Perfil › Privacidad y datos IA).
3. **L14-3 · nombres.** Los selectores usan los nombres de tono y estilo que ya ve el usuario en Ajustes (Equilibrado/Ahorrador/Precavido), no los nuevos de la maqueta: L14-10 (Personalizar IA) está pendiente y no se abren dos vocabularios.
4. **L14-3 · ejemplo.** Un solo ejemplo que junta las dos elecciones: una entrada según el tono y la frase de ejemplo del estilo (Normal va sin entrada: «datos sin adornos»).
5. **L14-4.** La ficha rosa abre el teclado al tocarla; las preguntas se envían como hoy. Si el servicio no responde, el saludo vuelve al de siempre con su aviso: no se ofrecen dos cosas que no se pueden hacer.
6. **L14-5 · fila.** Voz y Foto mantienen su palabra (L4-1 de Jürgen); la píldora «Yala IA» ajusta su margen para caber en el iPhone 17 Pro, y si no cabe, la fila sigue desplazándose como hoy. Texto dorado sólido en oscuro y dorado oscuro en claro (AA sobre blanco).
7. **L14-5 · botón flotante** de Registros y Estadísticas: mismo acabado (cristal, borde e icono dorado sólido, sin degradado), redondo como el «+» que tiene debajo. Una píldora con texto taparía más la tarjeta «Resumen inteligente».
8. VoiceOver de la píldora lee lo que se ve, «Yala IA».
9. Las cadenas que quedan sin uso (pasos 3, 4 y 5 viejos, «IA» de la píldora) se retiran de los 16 idiomas.
