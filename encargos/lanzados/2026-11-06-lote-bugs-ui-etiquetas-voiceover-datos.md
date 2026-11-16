# Lote · UI: etiquetas del Panel, VoiceOver del dictado y «Dónde viven tus datos»
toca: selector etiquetas Panel, VoiceOver dictado, Dónde viven tus datos

Rama base: origin/2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la libre. Simulador OK. Cierre autónomo. Termina con `/cerrar-total`. Commits y PR sin firma de IA.

## Contexto
Tres bugs chicos de UI/copy en backlog 2.3:
1. En 2.3, el selector de etiquetas de Nuevo registro (desde el Panel) no monta filas (tablero-en-2-3-el-selector-de-etiquetas-de-nuevo-dimd)
2. VoiceOver del dictado dice «el iPhone» también en el iPad (tablero-voiceover-del-dictado-dice-el-iphone-tam-9es7)
3. En una sesión solo de grupos, «Dónde viven tus datos» dice que viven en tu iCloud privado (tablero-en-una-sesion-solo-de-grupos-donde-viven-6dz5)

## Qué se pide
Arreglar los tres; capturas donde se vea; cards a `in qa`. Si el copy de «Dónde viven tus datos» en sesión solo-grupos pide decisión de producto, `preguntar-bot`.

## Qué NO hay que tocar
marketing/, cambios grandes de Ajustes.

## Cómo se sabe que está bien
Tres cards OK; gate verde; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué base se trabaja?** → `origin/2.3`; la rama del worktree nació de `2.2` y se reubicó antes de tocar nada.
Por qué: el encargo pide un PR contra 2.3. Alternativa descartada: rebasar después, que arrastraría commits de 2.2.

**D2 · «Dónde viven tus datos» en solo grupos: ¿hay que decidir copy?** → No. Ya se decidió (Jürgen, 2026-10-18, opción 1:
ocultar la fila) y está en 2.3 (`ProfileView`, `!isGroupsFocusedShell`; «Tu cuenta de Yala» la deja como texto). El ticket
del repo ya está en `done`; la card estaba vieja. Se verifica con sus dos XCUITest y captura, y la card pasa a QA sin código.
Por qué: medido en el árbol. Alternativa descartada: `preguntar-bot` por un copy que la decisión vigente ya hace innecesario.

**D3 · VoiceOver del dictado: ¿«el dispositivo» o sin sujeto?** → «el dispositivo», con el término de cada idioma que fijó
i9r1 (Gerät, appareil, apparaat, urządzenie, 端末, 设备), y un test por clave en `LocalizationParityTests`.
Por qué: es la convención de la casa para nombrar el aparato. Alternativa descartada: rama iPhone/iPad por `idiom`, que no
cubre el Duo ni Mac y contradice la regla de nombrar «dispositivo».

**D4 · Selector de etiquetas: ¿arreglo en la app o en el test?** → Lo decide la medición (vídeo del `.xcresult` y, si hace
falta, bisecar `origin/2.2..origin/2.3`). Si la app abre bien y es el test, se arregla el test sin tocar producto.
Por qué: el ticket no sabe aún cuál es. Alternativa descartada: elegir antes de medir.

**D5 · Simulador.** → Cola con `sim-lock.sh`; en la Max, si otro proyecto lo ocupa, segundo simulador (permiso de Jürgen del 6-nov).
