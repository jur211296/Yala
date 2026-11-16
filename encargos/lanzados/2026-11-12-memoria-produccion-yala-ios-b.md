Yala
# Encontrar y arreglar por qué Yala se cierra por exceso de memoria en producción
---
card: tablero-yala-se-cierra-por-exceso-de-memoria-wat-iq0m
toca: Yala/App/Services/, Yala/App/Utilities/, Yala/App/AppBootstrapper.swift, Yala/App/YalaAppDelegate.swift
esfuerzo: high
cierre: cierra-sola
---

Base: origin/2.3 en jur211296/Yala (2.2 está publicada y distribuida: no se toca). Un solo PR a 2.3 y cierre autónomo (cierra-sola) con `/cerrar-total` si el trabajo queda completo. Commits y PR sin firma de IA. No tocar producción, datos reales, marketing, trabajo de otras sesiones ni colas. Antes de actuar, revisa PRs y tablero para no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3. Simuladores: en la Max puedes usar un segundo simulador o el iPhone 14 por DeviceMCP; en la Mini, uno.

## Contexto
Sentry YALA-IOS-B (WatchdogTermination): iOS mata la app por usar demasiada RAM. https://yala-is.sentry.io/issues/YALA-IOS-B
- 17 casos en total. Regresión en producción con la build distribuida 2.2 (9). El último fue el 10-nov a las 20:25 Lima, en un iPhone 16 Pro Max (iPhone17,2) con iOS 27.2.1 y la app en primer plano. Ese iPhone NO es de Jürgen: es un usuario real.
- Sentry no trae stacktrace (un watchdog no lo deja).
- Arreglos previos que no bastaron: PR 827 (lote de crashes) y PR 875 (downsample de la foto de perfil y hang tracking, llevado a 2.2). La cifra sigue subiendo.
- El conector de Sentry dio 403 antes. Usa sentry-cli o la API con el token disponible en la máquina si existe; si no hay acceso de lectura, dilo con `BLOQUEANTE:` y no inventes datos.

## Encargo y criterio de terminado
1. Reúne la evidencia de Sentry de todos los eventos: breadcrumbs, pantalla y vista activas, tiempo de sesión, dispositivo, versión de iOS, memoria disponible, release, y si hay patrón (pantalla, tamaño de datos, fotos, IA, nube, widgets, imports).
2. Formula hipótesis y mídelas. Usa Instruments (Allocations, Leaks, VM Tracker) o memgraph en el simulador y en el iPhone 14, con un dataset grande (muchos registros, fotos, grupos), y recorre los flujos que señalen los breadcrumbs. Busca crecimiento sin techo: cachés de imágenes sin límite, ciclos de retención, cargas completas de Core Data o SwiftData, decodificación de imágenes a tamaño completo, gráficos de Estadísticas o listas sin paginar.
3. Arregla la causa raíz (o las causas medidas), con un test de regresión por causa que falle sin el arreglo.
4. Añade lo que haga falta para que el próximo caso traiga contexto: breadcrumbs de pantalla y de memoria, aviso de memoria baja (didReceiveMemoryWarning) registrado en Sentry. Sin datos personales.
5. Haz la review adversarial y pasa el gate del proyecto.
6. En el cierre pon la causa encontrada, con su evidencia y cifras de memoria antes y después, y cuánto confía en que sea la que vio el usuario. Si no se puede reproducir, deja medido lo que se descartó y la instrumentación nueva lista, y dilo claro: no declares resuelto lo que no lo está.
Deja la card en qa si hace falta confirmar en producción con la próxima build; no marques resuelto el issue en Sentry hasta que una build con el arreglo esté distribuida.

FIN

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo semi): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (Sentry por API, App Store Connect por `asc`, 2026-11-12).** De los 17 eventos de
YALA-IOS-B, 16 son de Yala Dev 2.2 (7) en el iPhone 14 de pruebas (iPhone14,7), del 5 al 10-nov, antes de que el PR 875
apagara ese aviso fuera de producción. El único de producción —2.2 (9), iPhone17,2, iOS 27.2.1— empezó a las
01:23:17 UTC del 11-nov, **5 minutos después de enviar la 2.2 a revisión de Apple** (01:17:53 UTC); el iPhone corría un
kernel `DEVELOPMENT_ARM64` (los de la calle son `RELEASE`), en `en_US`, recién instalado (primer registro de App Attest),
2 min 20 s de sesión, y la app volvió a abrirse 2 s después del último rastro. Ningún evento de los 17 trae un aviso de
memoria baja. La 2.2 (9) lleva 17 sesiones de 8 usuarios en producción y ese es su único cierre.

**D1 · ¿Es un usuario real?** → No, con alta probabilidad es el iPhone de revisión de Apple. Se dice así en el cierre y
no se declara resuelto nada. Por qué: kernel interno, hora y entorno casan con la revisión. Alternativa descartada:
tratarlo como regresión de un usuario y «arreglar» a ciegas.

**D2 · ¿Qué se arregla sin causa probada?** → Solo lo que se mida con crecimiento real. Candidato medido primero: las
fotos de recibo entran a tamaño completo (`UIImage(data:)` sin reducir) y viven en la hoja durante toda la lectura.
Si la medida lo confirma, se reducen al entrar a `max(2048, maxEdge del gateway)` px de lado mayor, con test que falla
sin el arreglo. Por qué: es el único camino donde unas pocas fotos de 48 MP suman cientos de MB. Alternativa
descartada: tocar cachés o fetches que la auditoría vio acotados.

**D3 · ¿Qué instrumentación?** → (a) la limpieza conserva el estado de los rastros de ciclo de vida
(`active`/`inactive`/`background`/`foreground`) y la acción de los de sistema (`LOW_MEMORY`, teclado), nada más; (b) un
contexto `memory` en Sentry con la memoria propia, lo que queda antes del límite y el pico, que el SDK guarda para el
próximo cierre por memoria; (c) un rastro `memory` al cruzar escalones de memoria y en cada aviso de memoria baja;
(d) un evento «Aviso de memoria baja» como mucho uno cada 10 min; (e) un rastro y una etiqueta con la pestaña elegida.
Sin títulos de pantalla ni nombres de clases: pueden llevar nombres de grupos o importes. Por qué: el evento de
producción llegó sin un solo dato útil porque la limpieza borraba el estado. Alternativa descartada: rastros de cada
hoja presentada (mucho cableado, poco valor frente a la pestaña).

**D4 · ¿El aviso de memoria baja también en desarrollo?** → Sí. El ruido de Yala Dev en YALA-IOS-B venía de cierres de
las herramientas, no de avisos de memoria, que solo manda iOS. Alternativa descartada: solo producción (perdería el
iPhone 14 de QA como canario).

**D5 · ¿Se resuelve el issue de Sentry y se cierra la card?** → No. La card va a `qa`: espera la próxima build
distribuida y la primera señal de la instrumentación nueva. El issue se queda abierto.

**D6 · Ficheros fuera de `toca:`** → `SceneNavigation.swift` (una línea en el `didSet` de la pestaña),
`ImageSelectionView.swift` y `ErrorReportScrubLogic.swift`. Se comprueba antes del PR que ningún PR abierto los toque.

**D7 · Lo que aparezca fuera del encargo** (p. ej. la limpieza convierte «between 2 and 3 seconds» de los App Hang en
«[monto] and [monto]») → a «Encontrado» y card, sin tocarlo aquí.
