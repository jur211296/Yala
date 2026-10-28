# S13b · Grupos: saldo inicial de un miembro en cualquier momento

## Qué hay que hacer, en una línea
Permitir fijar o editar el saldo inicial de un miembro ya aceptado desde la sección Miembros, con fecha, y que aparezca como registro del grupo.

## Contexto
- Jürgen 2026-10-28: no le deja poner saldo inicial a los miembros del grupo después de haberlos ya aceptado hace rato.
- Debe ser una opción válida dentro de la sección de miembros de un grupo, **no importa el momento**.
- Incluye **fecha del saldo inicial**.
- Entiende que aparece como **registro** en el grupo (igual que al aceptar con saldo).
- Hoy solo está disponible al aceptar al miembro (flujo de aprobación); falta el camino post-aceptación.
- Card: `tablero-grupos-saldo-inicial-de-un-miembro-en-cu-t3fq`
- Versión 2.2; rama base `origin/2.2` (o la base activa del proyecto).
- PR reciente de Grupos: #664 (admin tras wipe, etc.). No reabrir ese PR; trabajo nuevo en worktree propio.
- SQL g25_01 + Worker con owned_groups ya desplegados en staging/prod (contexto backend reciente; no es el foco de esta card).

## Qué se pide
1. En la sección **Miembros** de un grupo, ofrecer acción para fijar o editar el **saldo inicial** de un miembro ya aceptado (aunque se haya aceptado hace tiempo).
2. Pedir **importe** y **fecha** del saldo inicial (misma semántica que al aceptar).
3. Al guardar, crear/actualizar el movimiento como **registro del grupo** (mismo tipo/forma que el saldo inicial al aceptar), visible en el historial del grupo.
4. Si ya había saldo inicial, definir comportamiento claro (editar/reemplazar con registro coherente; no duplicar basura). Documenta en el PR lo que elijas si el producto no lo fija.
5. Tests unitarios o de UI mínimos del camino feliz + miembro aceptado hace rato.
6. Copy en los idiomas que ya toque el flujo de miembros/saldo (al menos es + en-US; sigue el patrón del repo).

## Qué NO hay que tocar
- No reabrir el flujo de aceptación salvo para reutilizar helpers.
- No cambiar reglas de admin (card y1cd / g25_01).
- No refactor masivo de Grupos ni del Worker.
- No CloudAgent; solo este worktree.

## Cómo se sabe que está bien
- Desde Miembros, con un miembro aceptado hace rato, se puede fijar saldo inicial con fecha.
- Aparece como registro en el grupo.
- Criterio de la card: hechaCuando de `tablero-grupos-saldo-inicial-de-un-miembro-en-cu-t3fq`.
- Build/tests del área en verde; PR a la rama base de 2.2.
- La sesión termina con `/cerrar-total`.

## Dependencias
La sesión arranca ya sobre la rama base del proyecto (Yala: origin/2.2), sin esperar CI ni merge del PR anterior; justo antes de abrir PR, git fetch + un solo rebase sobre esa rama base, y build/simulador (si aplica) una vez después.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** La premisa «hoy solo se puede al aceptar» es falsa a medias: Miembros ya
tiene, abajo del todo, una sección «Saldos iniciales» con «Añadir saldo inicial» (solo quien creó el grupo). Lo que
falta de verdad: (1) no hay forma de llegar desde la persona —hay que bajar a esa sección y elegirla a mano—;
(2) el saldo se fecha SIEMPRE en el día en que se creó el grupo (`setOpeningBalance`/`updateOpeningBalance` escriben
`group.createdAt`), así que en Registros del grupo cae al fondo, en una fecha que nadie eligió, y editarlo lo vuelve a
mover ahí; (3) un segundo saldo entre las mismas dos personas crea otro, no reemplaza.

**D1 · ¿Dónde vive la acción?** → En el menú «···» de cada miembro activo, «Saldo inicial», solo para quien creó
el grupo y con el grupo no congelado. Abre el formulario con esa persona en «Quién debe»; si esa persona ya tiene
exactamente un saldo inicial (como deudora o acreedora), abre ése para editarlo.
Por qué: es el sitio donde Jürgen lo buscó (la persona) y no mueve nada de la pantalla. Alternativa descartada: un
botón por fila (ensancha una fila que ya va justa con el «te debe»).

**D2 · ¿Qué fecha lleva?** → Campo «Fecha» en el formulario; al crear, hoy; al editar, la que tenía; nada en el
futuro. Esa fecha es la del registro en el grupo y la del movimiento de la cuenta «Grupos». Los saldos ya guardados
conservan su fecha (la de creación del grupo) hasta que alguien los edite.
Por qué: el encargo pide la fecha y «misma semántica que al aceptar» — al aceptar hoy no se pedía, así que el
formulario es uno y gana el campo para los dos caminos. Alternativa descartada: por defecto la fecha de creación del
grupo (es justo lo que esconde el registro al fondo).

**D3 · ¿Qué pasa si ya había saldo inicial?** → Uno por pareja y moneda: guardar un saldo nuevo entre las mismas dos
personas (en cualquier sentido) y en la misma moneda EDITA el que había —importe, sentido y fecha— en vez de crear
otro. En otra moneda es otro saldo. Vale también para el atajo de aceptar y para «Añadir saldo inicial».
Por qué: «no duplicar basura»; dos saldos de la misma pareja y moneda solo se suman, y el que mira Registros ve dos
filas para una sola deuda de partida. La edición pasa por el guard de liquidaciones confirmadas de siempre.
Alternativa descartada: avisar y preguntar (una decisión que la app puede tomar sola sin mover datos de nadie más).

**D4 · ¿Quién puede?** → Solo quien creó el grupo, como hasta hoy. Por qué: el encargo prohíbe cambiar reglas de
administración (y1cd / g25_01).

**D5 · ¿Toca backend o esquema?** → No. La fecha ya viaja: es la `date` del gasto, sin columna nueva.

**D6 · ¿Copy nuevo?** → Ninguno: «Saldo inicial» (`editorTitle`) y «Fecha» (`dateLabel`) ya existen en los 16
idiomas. Por qué: menos superficie que traducir; las dos palabras dicen exactamente lo que hacen.

**D7 · Tests** → Unit del servicio (fecha elegida al crear y al editar, reemplazo por pareja y moneda, miembro
aceptado hace meses) y de la lógica pura de «qué abre la acción del miembro»; XCUITest del menú del miembro →
formulario con la persona puesta y el campo de fecha.
