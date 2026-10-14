# Auditoría UX 2.2 · lote 6: primera vez con datos previos o en la nube

> **ALCANCE ESTRICTO:** solo los 9 flujos del lote 6. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: tablero-auditoria-ux-2-2-lote-6-primera-vez-con-z12j (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 6).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-5-primeros-dias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 6 (9 flujos)
Restaurar desde iCloud al instalar; entrar con cuenta de Yala; crear cuenta en la nube; aviso de Apple ID con cuenta previa; onboarding terminado en otro aparato; aviso tardío de datos en iCloud; pasar de solo grupos a Yala completo; consentimiento de la nube; reabrir Yala tras restaurar. Usa los hooks de QA/semillas para simular iCloud y la cuenta de Yala; NO toques el esquema de CloudKit ni datos reales en la nube. El lote 1 ya decidió L1-4 («Reabre Yala» con línea de privacidad, PR #485): revisa sobre eso.

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L6-1, L6-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 6 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones.

## Elecciones de UI: variantes y esperar
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L6.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Entonces:
- `xcrun simctl shutdown all`;
- avisa con `python3 ~/.claude/hooks/avisar_grok.py --avisar cierre-resumen --texto "Lote 6: variantes listas para elegir: <ruta del HTML> · PR: <url si hay>"`;
- **NO ejecutes /cerrar-total. Quédate viva** esperando la elección de Jürgen (llegará por decirle). No borres el worktree.
Si no hay ninguna elección de UI, cierra normal con /cerrar-total.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo se ven en el simulador los estados que dependen de iCloud real, Apple/Google o el backend?** → Con una maqueta local `-mock6 <id>` (fichero `Yala/App/Mock6.swift` + enganches de una línea, solo `DEBUG`) que fuerza el estado de cada pantalla y la presenta por su camino real en `ContentView`. No se commitea; se guarda como `maquetas-lote-6.patch` en la entrega.
Por qué: el simulador no tiene iCloud, SIWA ni App Attest; los hooks `-uitest-*` existentes cubren la navegación pero no las fases internas. Alternativa descartada: hooks nuevos en producción (crecen la superficie de test sin que nadie los pidiera).

**D2 · ¿Qué pantallas se recorren de verdad y cuáles con maqueta?** → De verdad: Welcome, «Ya tengo una cuenta», «Es mi primera vez», intro de entrar/crear cuenta, consentimiento, Restaurar sin iCloud, activación de Yala completo desde solo-grupos (con `-uitest-group-invite`, `-uitest-cloud-chooser`, `-uitest-fake-attest-support`, `-uitest-fake-icloud`). Con maqueta: las fases de Restaurar, del sign-in en la nube, del aviso tardío, el final de la activación, «reabre Yala» y el toast del onboarding terminado en otro aparato. El informe dice cuál es cuál.

**D3 · ¿Qué cuenta como bug claro que se arregla en el PR?** → Lo que contradice un hecho (copy falso, plural roto, botón que no hace lo que dice, texto cortado) y se arregla sin decidir producto. Lo que cambia el flujo o el aspecto es mejora con card para Jürgen.

**D4 · Los 9 tickets abiertos del lote** → No se rehacen: si una mejora coincide, se cita el ticket y no se duplica.

**D5 · Simulador** → Uno (iPhone 17 Pro, iOS 27.0), `nice -n 10 -jobs 2`, nada de 9:00 a 11:00 Lima; `shutdown all` al terminar.

**D6 · Elecciones visuales** → Si alguna mejora es visual, `variantes-L6.html` con 2–3 variantes renderizadas en el simulador y la sesión se queda viva esperando a Jürgen (no `/cerrar-total`).
