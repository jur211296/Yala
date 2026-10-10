---
id: wipe-copy-reads-one-axis-while-the-sheet-reads-two
status: qa
priority: medium
area: "sesiones, settings, copy"
created: 2026-09-13
updated: 2026-10-10
source: "review adversarial del PR-B del paso 12 (`shell-derives-from-two-session-axes`), lente «lo que borra datos»"
---

# «Vaciar datos» promete menos de lo que borra en una de las cuatro celdas

## Qué pasa

En la pantalla de «Vaciar mis datos» hay dos cosas que describen el mismo acto y **no leen lo mismo**:

| | Qué lee | Dónde |
|---|---|---|
| El párrafo de la pantalla | **un** término: ¿hay sesión privada? | `UserDefaults.../UserDataResetView.swift` (el `Text` bajo el título) |
| La hoja de alcance y el borrado | **dos**: ¿hay sesión privada? **y** ¿el store espeja a iCloud? | `scopeOperation` → `DestructiveScopeLogic.wipeOperation` |

La celda donde divergen es **sin sesión privada + el store personal espejando** (una instalación
solo-grupos anterior al paso 5, que monta `.iCloudMirror`):

- La hoja resuelve `.wipeDataFull`: 📱 destructivo, ☁️ destructivo, con su aviso de que alcanza a los
  demás dispositivos. Y el borrado sale de verdad a iCloud, porque el espejo está adjunto.
- El párrafo dice `settings.resetDataDescriptionGroupsOnly`: «restablecerá tu perfil y tus preferencias
  de Yala a un estado inicial».

O sea: **la pantalla promete menos de lo que va a pasar**, que es la dirección cara del error. La hoja
de confirmación sí lo dice entero, así que hay un segundo gesto por delante — pero el texto que la
persona lee primero es el que miente.

## Por qué no se arregló en el PR que lo encontró

Es **anterior** al barrido: el `Text` no cambió en ese PR (comprobado contra `HEAD`). Lo que cambió fue
el comentario de al lado, que pasó a afirmar «el MISMO eje que `scopeOperation`, y tiene que serlo» —
una afirmación falsa que la review tumbó y que ya está corregida en el código, apuntando aquí.

Arreglarlo es cambiar de qué deriva una copy, o sea producto: hay que decidir si el texto pasa a
derivarse de `scopeOperation` (lo que la hoja va a hacer) o si se reescriben las dos cadenas para que
ninguna prometa alcance. Eso no cabe en un PR cuyo objeto era retirar código.

## Lo que hay que decidir

- **Opción A (recomendada):** el párrafo deriva de `scopeOperation`, igual que la hoja. Una sola fuente.
- **Opción B:** dos cadenas nuevas que describan el alcance sin comprometerse, y que la hoja siga siendo
  quien lo nombra entero.

## Criterios de aceptación

- [x] El texto de la pantalla y el alcance de la hoja no pueden discrepar en ninguna de las cuatro celdas
      del ADR 2026-09-09, y hay un test que recorre las cuatro (hoy `DestructiveScopeLogicTests` cubre
      `wipeOperation` con sus dos variables, pero **nada** cubre la pareja texto ↔ operación).
- [x] El comentario de `UserDataResetView` que hoy apunta a este ticket se actualiza o se retira.

## Decisión de Jürgen (2026-10-07)

Opción A: **el texto sale de lo mismo que decide qué se borra**. El párrafo de la pantalla deriva de `scopeOperation`,
igual que la hoja; una sola fuente. Los criterios de aceptación de arriba no cambian.

## Hecho (2026-10-10)

Opción A implementada, sin tocar qué se borra ni la hoja:

- `DestructiveScopeLogic.wipeDescription(for:)` mapea la operación a qué alcance nombra el párrafo:
  `.wipeDataFull` → texto completo (`settings.resetDataDescription`), `.wipeDataGroupsOnly` → perfil y
  preferencias (`settings.resetDataDescriptionGroupsOnly`), el resto de operaciones → sin párrafo. El
  `switch` es exhaustivo: una operación de Vaciar nueva no compila hasta decidir su texto.
- `UserDataResetView` pinta el párrafo con `resetDescriptionText(for: scopeOperation)`, la misma
  operación que recibe la hoja. El comentario que apuntaba aquí se retiró.
- Sin claves nuevas: los dos textos existentes ya nombran el alcance de cada operación.
- `YalaTests/WipeDescriptionParityTests`: fija la discrepancia vieja (la regla de un término difiere en
  exactamente la celda sin sesión privada + espejo) y recorre las cuatro celdas exigiendo que texto y
  operación coincidan. Control rojo: con el cuerpo viejo de la pantalla
  (`PrivateSessionMark.hasPrivateSession() ? … : …`) el test falla.

Para quien usa la app: en las celdas alcanzables hoy el texto no cambia. Solo cambia en la instalación
solo-grupos anterior al paso 5 con el espejo montado, que ahora lee el párrafo completo, el mismo
alcance que la hoja le enseña al tocar.

## Guion de device-QA

No hay capturas: la celda que cambia (solo grupos + store que espeja) no se monta en el simulador sin
inventar estado, y en las otras tres el texto es el mismo de antes. El test unitario cubre la celda
divergente; el guion comprueba que las alcanzables no retroceden.

1. Instala el build de TestFlight que trae este cambio en tu iPhone, con tu sesión privada habitual.
2. Ve a **Perfil → Ajustes → Vaciar datos**.
3. Lee el párrafo bajo «Vaciar todos tus datos»: debe decir que se eliminan de forma permanente tus
   cuentas, transacciones, presupuestos… (el texto completo).
4. Toca «Vaciar mis datos» (en rojo): la hoja debe enseñar el borrado completo (📱 y ☁️ en rojo). **Cancela**, no
   confirmes.
5. Si tienes a mano un dispositivo con sesión **solo grupos** (sin vida personal, instalación reciente):
   repite 2-4. El párrafo debe hablar de restablecer perfil y preferencias, y la hoja decir que los
   grupos no se tocan. Cancela.
6. Si ambos casos cuadran, el ticket pasa a `done`.
