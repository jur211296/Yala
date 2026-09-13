---
id: wipe-copy-reads-one-axis-while-the-sheet-reads-two
status: backlog
priority: medium
area: "sesiones, settings, copy"
created: 2026-09-13
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

- [ ] El texto de la pantalla y el alcance de la hoja no pueden discrepar en ninguna de las cuatro celdas
      del ADR 2026-09-09, y hay un test que recorre las cuatro (hoy `DestructiveScopeLogicTests` cubre
      `wipeOperation` con sus dos variables, pero **nada** cubre la pareja texto ↔ operación).
- [ ] El comentario de `UserDataResetView` que hoy apunta a este ticket se actualiza o se retira.
