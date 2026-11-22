Yala
# Captura por foto: la IA reconoce el comercio, y atajo del banco y suscripciones parte 2 (B2, B3 y S2)
---
toca: Yala/App/Views/Image/ImageSelectionView.swift,gateway/src/ai/tasks.ts,gateway/src/ai/schemas.ts,Yala/App/Logic/AtajoBanco/,Yala/App/Intents/BankNoticeIntent.swift,YalaTests/CapturaAtajoParte2/,tickets/backlog/2026-11-21-captura-foto-comercio-atajo-banco-parte-2.md,tickets/done/2026-11-21-captura-foto-comercio-atajo-banco-parte-2.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen aprobó el 21-nov (08:39 Lima, decisión t1868-reconfirma) este lote de la auditoría `docs/auditorias/2026-11-21-decisiones-vs-2-3.md`. Decisiones:
- 75 (t1678u, 15-nov): «mejorar la predicción de categoría y cuenta de la IA (voz e imagen sobre todo)… usar el conocimiento general de la IA sobre comercios».
- 66 (t1661u, 14-nov): «Atajo del banco y pagos recurrentes: se toman todas las opciones recomendadas de la propuesta visual (A1 a A6 y S1 a S5…)». Falta la segunda parte: B2, B3 y S2.
Verifica primero con `git log origin/2.3` qué ya entró. No toques producción ni despliegues del gateway; si hace falta desplegar, déjalo anotado. Cards relacionadas: «IA: predecir mejor categoría y cuenta en voz e imagen», «Atajo del banco: registrar desde la notificación…» y «Dos suscripciones de la misma marca se anulan…»; reutiliza las que cubran el trabajo.

## Qué hacer
1. Foto: que la IA reconozca el comercio y lo proponga con su categoría y cuenta.
2. Atajo del banco: implementa B2, B3 y S2 según la propuesta visual del repo.
3. Pruebas en `YalaTests/CapturaAtajoParte2/` y, en el gateway, pruebas de vitest para el campo nuevo.

## Criterios de aceptación
- Una foto de recibo propone el comercio correcto en los casos de prueba.
- B2, B3 y S2 funcionan como en la propuesta visual.
- Capturas antes y después; `tests`, `coverage-index` y `gateway` en verde.

## Cómo verificar y entregar
- Puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP.
- Capturas antes y después en el cierre.
- La entrega visual se hace como artifact de Claude.
- Trabajo solo en tu rama de encargo; no toques archivos que no estén en `toca:`.

Índices compartidos: `docs/TICKETS.md` y `qa/coverage-index.json` no van en `toca:`; edítalos solo al final, justo antes del PR, tras `git rebase origin/2.3`, resolviendo por fila o área sin pisar lo de otra sesión.

Termina con /cerrar-total cuando el PR esté dentro de 2.3.
## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en autónomo, modo nocturno)

Medido en `origin/2.3` el 22-nov: B0, B1 y S1 entraron; ni B2, ni B3, ni S2. La cuenta por los últimos 4 ya existe
(`CuentaSolaAlLeer`, parte 1), así que B2 no necesita esquema.

1. **Foto, comercio y categoría.** La IA devuelve un campo nuevo, `merchantKind`, de una lista cerrada (supermercado,
   restaurante, farmacia, combustible…), y el teléfono lo traduce a una subcategoría del usuario. No viaja nada nuevo
   (ni nombres de categorías ni historial): vale igual en iCloud y en la nube. El comercio se pide por su nombre
   comercial conocido. Orden: lo que recuerda la persona › la IA › el banco de 666 comercios del teléfono (solo sus
   categorías sin duda). El aviso del banco, que no pasa por la IA, usa ese mismo banco. La cuenta ya la elige la
   escalera común (parte 1). Medición con el modelo real: no en la Max (solo tiene la clave de Anthropic del banco).
2. **Fuera de la foto**: el histórico compartido entre usuarios de la nube (la card pide que lo decida Jürgen) y la voz
   (ya recibe la lista de subcategorías del usuario).
3. **B2, dónde vive**: «Lo que Yala apunta solo» no existe; la propuesta dice que entonces va en Ajustes. Fila «Avisos
   del banco» debajo de «Siri y Atajos», fuera en solo grupos.
4. **B2, atajos por enlace**: no se pueden publicar esta noche (cada atajo lleva el disparador de la app de su banco y
   el iPhone 14 no tiene ninguna). Guía con los pasos a mano (I1, el respaldo que la propuesta deja dentro de I2) y el
   hueco del enlace por banco preparado: cuando exista, sale el botón «Añadir a Atajos».
5. **B2, estado**: sale de lo que llega: esperando, funcionando, silencio (solo si antes llegaban con frecuencia) y
   pausado. Contadores del mes. Pausar descarta lo que llega sin guardarlo. Cuenta por defecto por banco.
6. **B3, correo de Mail**: la misma acción con un parámetro opcional «Origen» (Notificación por defecto, o Correo). El
   correo se recorta (fuera el pie legal) y se leen «Monto:» y «Comercio:». La Bandeja dice «Aviso de BCP» en los dos
   casos: cambiar la evidencia del borrador rompería la etiqueta en builds anteriores.
7. **S2**: en Pagos planificados, tarjetas «subió/bajó de precio» (Actualizar / Dejar así) y «dejó de cobrarse»
   (Pausar el pago / Sigue activo). Pausar = `isActive = false`, como su editor. Bloque de Estadísticas: fuera.
8. **Card «Dos suscripciones de la misma marca se anulan»**: entra. Dos montos fijos intercalados de una marca = dos
   series; una subida de precio (no intercalada) sigue sin proponerse.
9. **Fuera de `toca:`**: `gateway/src/ai/routes.ts` (ahí vive `PHOTO_SCHEMA`), `VisionDraftFactory`,
   `ImageVisionService`, `PagosRecurrentes/`, `ProfileView`/`ProfileDestination`, vistas nuevas y su tabla de textos.
   No hay otra sesión de Yala viva; la pausada de reglas de cuenta toca `ImageSelectionView` y `DraftBuilder`, que no
   se tocan.
10. **Gateway**: no se despliega. Sin desplegar, OpenAI sigue con `json_object` y el prompt de la app ya pide el
    campo; el esquema solo lo imponen Anthropic y Gemini.
