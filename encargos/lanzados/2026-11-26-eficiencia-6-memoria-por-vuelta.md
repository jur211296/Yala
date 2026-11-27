Yala
# Eficiencia 6: la memoria deja de subir ~25 MiB por cada vuelta a Yala (investigar y corregir)
---
toca: Yala/App/ViewModels/PanelViewModel.swift,Yala/Services/Spotlight/SpotlightIndexService.swift,Yala/App/Logic/MemoriaPorVuelta,YalaTests/EficienciaMemoriaPorVuelta,docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-6-memoria-por-vuelta/,tickets/backlog/2026-11-26-eficiencia-6-memoria-por-vuelta.md,tickets/done/2026-11-26-eficiencia-6-memoria-por-vuelta.md
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: no
depende: Yala/eficiencia-5-render-del-scroll
---

Lote del plan de eficiencia que salió del análisis de calentamiento, batería y scroll en el iPhone 14. Va al final, como recomienda el informe, porque se mide sobre lo que dejaron los lotes 1 a 5 y toca archivos que cambian el 3 y el 4.

## Qué se pide
1. Allocations en 10 ciclos en el iPhone 14 para aislar qué crece (~25 MiB por vuelta: 238 → 363 MiB en 5 ciclos en el informe).
2. Comprobar si las recargas completas dejan vivas las filas de SwiftData (contexto que no se resetea), en el Panel y en Spotlight.
3. Corregir lo que aparezca y fijarlo con un test de memoria por ciclo si es posible. Si la causa está en un archivo fuera de `toca:`, anótalo en «Saltado o asumido sin preguntar» con el motivo.
4. Además, **pasada final de verificación** en el iPhone 14 con los guiones del informe (vuelta, reposo, scroll, calor, cierres y energía) para dejar el antes/después de todo el plan de eficiencia en un solo artifact.
- Pruebas nuevas en `YalaTests/EficienciaMemoriaPorVuelta/`.

## Mejora esperada y cómo se mide
Memoria estable (± 10 MiB) tras el ciclo 2 en 10 ciclos (Activity Monitor / Allocations), y la pasada final completa contra las cifras del informe.

## Qué NO hay que tocar
- Nada fuera de `toca:`; si necesitas otro archivo, anótalo en «Saltado o asumido sin preguntar» con el motivo.
- Lo de los otros lotes del plan (cada uno va en su sesión).

## Contexto común
- Informe de origen: `docs/qa/rendimiento-iphone14-2026-11-26/README.md` (sección «Lotes propuestos» y «Causas raíz, ordenadas por impacto medido»), con datos en `docs/qa/rendimiento-iphone14-2026-11-26/datos/` y los guiones de medición en `docs/qa/rendimiento-iphone14-2026-11-26/scripts/` (por ejemplo `scripts/pasada.sh`). Lo hizo la sesión «Análisis profundo de calentamiento, batería y scroll en iPhone 14» el 26-nov midiendo en el iPhone 14 de Jürgen con un almacén de 16.004 movimientos. Si al arrancar el informe todavía no está en `origin/2.3`, búscalo en la rama `encargo/2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14`.
- Pedido de Jürgen (26-nov, 10:44 Lima): «encola los 6 lotes de mejoras de eficiencia de la sesión del calor». Él siente que Yala calienta el teléfono al ir y volver de otra app y que el scroll al volver va lento.
- Las líneas citadas en el informe son de `origin/2.3` en `b5c6e98c5`; confírmalas en el código de hoy, porque otros lotes ya pueden haber cambiado esos archivos.

## Cómo medir
- **Antes y después en el iPhone 14 real** («iPhone de JURGEN», conectado por cable a la Max) con DeviceMCP, `devicectl` y `xcrun xctrace`, usando los mismos guiones y el mismo almacén de 16 k que el informe, para que las cifras sean comparables. Las cifras de rendimiento solo valen si salen del iPhone 14; el simulador sirve para desarrollar y para las pruebas, no como evidencia de rendimiento. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los que enciendas.
- Al arrancar, comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que el iPhone no está bloqueado. Si está bloqueado o no responde: en semiautónomo, pídele a Jürgen que lo desbloquee (y que ponga Bloqueo automático en «Nunca» mientras dure la prueba) y espera con la sesión viva; en nocturno, termina lo que no necesite el teléfono, deja checkpoint y anota la medición pendiente como `BLOQUEANTE:` con el error exacto. Si el iPhone lo está usando otra sesión, espera en tramos cortos con aviso.
- Deja las mediciones de este lote en `docs/qa/rendimiento-iphone14-2026-11-26/despues-<slug-del-lote>/` (resumen numérico antes/después y extractos de trazas, nada pesado) y compáralas contra la «mejora esperada» del informe.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Cada cambio con su prueba en la carpeta de pruebas de este lote. Textos nuevos, si hiciera falta alguno, solo en una tabla de strings propia del lote en cada `.lproj`, nunca en `Localizable.strings`.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo; para medir, compilación de perfilado (Release con símbolos) instalada como Yala Dev en el iPhone 14. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Nada de cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen. No cambies lo que la persona ve, salvo lo que diga el lote.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- No borres datos del iPhone ni la base de desarrollo.

## Cierre
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Entrega: artifact visual de Claude con antes/después medido en el iPhone 14 (cifras y gráficas), qué se cambió y qué quedó pendiente; enlázalo en el cierre. No Markdown, PDF ni documento de puro texto.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué build se mide el «antes» del lote?** → `origin/2.3` (lotes 1-4) fusionado en local con la rama del
lote 5 (aún en cola de auto-merge), en copia de perfilado `Release-Dev` + `DEBUG` solo en la copia, como los lotes previos.
Por qué: el encargo declara `depende: eficiencia-5`, y el lote se mide sobre lo que dejaron 1-5. Alternativa descartada:
esperar el merge del lote 5 (la regla de casa dice no esperar a otros PR).

**D2 · Medido: la memoria ya no sube por vuelta (108 → 110 MiB en 10 ciclos; antes 238 → 363). ¿Qué se corrige?** → No se
toca código de la app. Se comprueba además con una copia que FUERZA la recarga completa del Panel y de Spotlight en cada
vuelta (interruptor temporal, solo en la copia): tampoco crece. Por qué: el encargo pide corregir «lo que aparezca», y no
apareció nada; cambiar código sin defecto medido es alcance no pedido. Alternativa descartada: «optimizaciones» de memoria
preventivas (reset de contextos, etc.) sin una cifra que las justifique.

**D3 · ¿Test de memoria por ciclo?** → Sí, en `YalaTests/EficienciaMemoriaPorVuelta/`: N recargas completas del Panel y
N lecturas de Spotlight sobre un almacén en disco, con la huella física del proceso medida tras cada ciclo y tope de
crecimiento del ciclo 2 al último; con un control positivo que retiene un contexto con sus filas por ciclo (la fuga que el
encargo sospechaba) y debe superar el tope. Por qué: fija la clase de fallo sin depender del iPhone. Alternativa
descartada: contar objetos registrados del contexto (SwiftData no lo expone).

**D4 · ¿Qué entra en la pasada final y con qué build?** → La misma build del D1 (es el código final: este lote no cambia la
app). Guiones del informe: vuelta (Time Profiler + Hitches + Thermal, 10 ciclos), reposo (E), scroll por pantallas (D, con
el conductor del lote 5 en Panel, Registros y Compartido), energía (Power Profiler, J), memoria (Activity Monitor, F) y
cierres (`.ips` y `cpu_resource` del iPhone). Por qué: el encargo lo pide para dejar todo el plan en un artifact.
Alternativa descartada: Estadísticas, Pagos y Bandeja en la pasada D (rutas por toques que dependen de la tarjeta de Más;
ya las midió el lote 5).

**D5 · Guiones que faltan en el informe (`xtparse.py`, `perfil_lector.py`).** → Se escriben de nuevo dentro de la carpeta
de este lote. No se toca `scripts/` del informe (fuera de `toca:`); se anota en «Encontrado».
