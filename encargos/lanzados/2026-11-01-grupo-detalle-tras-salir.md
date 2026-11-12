# Grupos: el detalle del grupo deja de leer el grupo después de salir de él

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `grupos-detalle-tras-salir` · Sesión cola **S35g** · al cerrar → **S36** (`barrido-qa-2-2-b`).

## Contexto
Hallazgo de la sesión formularios-modelo-borrado-b (PR #713, 2026-10-31): al salir de un grupo, la pantalla de detalle del grupo puede seguir leyendo el modelo del grupo que ya se borró, el mismo tipo de fallo que en iOS 27.x puede cerrar la app. Detalle y diagnóstico en el ticket `tickets/backlog/group-detail-reads-the-group-after-leaving-it.md`; leerlo primero, junto con el patrón aplicado en el PR #713.

## Qué hacer
1. Reproducir o confirmar con un test el acceso al grupo borrado después de salir.
2. Aplicar el mismo patrón del PR #713 al detalle del grupo y a lo que lo abre, sin cambios visibles.
3. Tests unitarios y de UI relevantes en verde; mover el ticket a cerrado.
4. PR a 2.2 con auto-merge. Card del tablero a done (o in qa si necesita prueba en iPhone, con guion corto).

Hallazgos nuevos: van como cards de 2.2 en ready to launch, nunca a backlog.

Termina con /cerrar-total.

## Paso 0

Decidido sin nadie delante (MODO cierra-sola); lo asumido, marcado.

- **Qué se ve con el grupo borrado mientras el detalle se va** (lo que el ticket dejaba por decidir): el fondo y el
  título, sin contenido, como Ajustes del grupo desde gxa9. *Asumido*: es el molde ya aceptado en #713 y solo dura la
  animación de salida. Guardar una copia de todo lo que pinta el detalle sería un cambio mucho mayor.
- **Título**: el nombre de la última carga (`viewModel.groupName`), no vacío.
- **Hojas**: solo Ajustes se sigue construyendo con el grupo borrado (ya guardada en gxa9); las demás no pintan nada.
- **ViewModel**: suelta con `releaseDeletedGroup()` (molde `releaseDeletedAccount`); la guarda del VM mira `isDeleted` y
  la marca, no `modelContext == nil` (verdadero en los modelos sin insertar de los tests, regla de gxa9).
- **Quien lo abre**: `GroupsContainerView` solo lee `persistentModelID`; se fija con scan, sin cambio.
- **Reproducir**: el simulador 27.0 no aborta y salir pide servidor ⇒ se confirma con unit + scan + mutantes; la prueba
  real es device-QA ⇒ ticket y card a `qa` con guion corto.
