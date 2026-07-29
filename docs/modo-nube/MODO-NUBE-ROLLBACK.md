---
created: 2026-07-29
updated: 2026-07-29
tags: [modo-nube, grupos, rollback, runbook]
status: active
---

# ROLLBACK de Grupos — runbook

**Para qué existe.** Hasta ahora, si Grupos se rompía en producción había un botón: apagar
`groupsBackendEnabled` en remoto y el canal volvía a CloudKit en segundos, sin build nuevo. **La Fase 3
borra el transporte CloudKit**, así que ese botón deja de devolver nada: apagarlo dejaría Grupos sin
ningún canal. Desde entonces el único rollback es **revertir el build**, y eso hay que tenerlo escrito
ANTES de necesitarlo — cuando algo se rompa, nadie va a reconstruir esta lista.

Requisito de entrada de la Fase 3 ([[MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS]] §6).

---

## 0 · Lo primero: hoy esto está FRÍO

`CloudSyncFlags.groupsBackendCompiledDefault = false` (`CloudSyncFlags.swift`). El canal backend está
apagado **en compilación**, y el flag remoto solo puede MATAR, nunca encender. ⇒ **en producción hoy
Grupos funciona por CloudKit y todo lo del canal nuevo está inerte.**

Consecuencia práctica: **revertir las Fases 1 y 2 hoy es casi un no-evento para el usuario final.** Este
runbook se vuelve caliente el día que se encienda el compilado (release **2.1**). Antes de esa fecha, un
rollback cuesta un revert y una release; después, cuesta lo que dice el §3.

---

## 1 · Los commits, por fase y en orden de revert

Revertir siempre **de abajo hacia arriba** dentro de cada bloque, y los bloques en el orden en que
aparecen aquí (Fase 3 antes que Fase 2 antes que Fase 1).

### Fase 2 — los 7 re-cableos (rama `2.0.5`)

| Pieza | Commit |
|---|---|
| 2.7 · seam del handover | `3e5f9740` |
| 2.6 · test de identidad (cierre del gap) | `45c27792` |
| 2.6 · identidad del miembro | `08298365` |
| 2.6-pre · el predicado se muda a `GroupBackendIdentityLogic` | `8e666074` |
| 2.5 · `syncNow` → drain del backend | `c3aee764` |
| 2.4 · consultas SwiftData → `GroupService` | `632c951f` |
| 2.3 · freeze en soft-delete | `4a51d9c0` |
| 2.2 · notificaciones de miembro | `ba95f62a` |
| 2.1 · notificaciones de grupo | `bed60a92` |

### Fase 1 — cierre del servidor y muerte de la migración

| Paso | Commit | ¿Revert de git lo deshace? |
|---|---|---|
| 1.1 · cerrar `migrate_group` en el gateway | `21dcd465` | **NO por sí solo** — ver §2 |
| 1.3–1.5 · borrar la maquinaria de migración en el cliente | `5010db6a` | **Sí**, limpio |
| `migrate_group` inerte de verdad (revoke) | `45c32a41` | **NO** — el commit solo mueve el snapshot `.ddl`; ver §2 |
| scripts de migración de D1 | `03ee208d` | irrelevante (solo `package.json`) |
| guard del umbral de forzado de versión | `69092b24` | irrelevante (solo un test) |

### Fase 3 — cuando exista

Sus 2 commits van AQUÍ, arriba de todo, y hay que **anotarlos en esta tabla en el mismo commit que los
crea**. Sin eso este runbook queda desactualizado el día que más falta hace.

> **NO revertir** los commits ajenos intercalados: `66960f7d` (cover de la bandeja), `bd9435b8` (salir
> del último grupo), `5c84df88` (deeplink del smoke), `b1a5033f`, ni ningún `docs(...)`. No son de las
> fases y revertirlos reabre bugs que ya se pagaron.

---

## 2 · Lo que un `git revert` NO recupera

**Esta sección es la razón de ser del documento.** Tres de los efectos vivos en producción **no viven en
git**, así que un revert da una falsa sensación de haber vuelto atrás:

| Qué | Cómo se activó | Cómo se deshace de verdad |
|---|---|---|
| **404 de `migrate_group`** en el gateway | un **deploy** del Worker (producción, deployment `09bfa839`) | revertir el código **y volver a desplegar**: `npm run deploy:production` (= `wrangler deploy --env production`; su `predeploy` sincroniza el manifest, así que usar el script de npm y no `wrangler` a pelo) |
| **`REVOKE EXECUTE` de `migrate_group`** en Supabase | **SQL ejecutado a mano** en los DOS entornos | un `GRANT EXECUTE ... TO authenticated` explícito, entorno por entorno. Requiere OK del owner y re-enlazar el conector al entorno correcto |
| **Migración de D1 aplicada** | `npm run migrate:production` | a mano: `gateway/migrations/` solo tiene `0001_init.sql` y `0002_account_entitlements.sql`, **ninguna trae `down`** |

⇒ **revertir la Fase 1 en git NO reabre la migración de grupos.** Si algún día hiciera falta volver a
migrar un grupo vivo a la nube, el revert es el primer paso de tres, no el único.

### Y lo que no se recupera de ninguna manera

- **Los grupos born-backend.** Un grupo creado en el canal nuevo **nunca tuvo zona CloudKit**, así que un
  build sin canal backend no puede verlo por ninguna vía. No es pérdida de datos (siguen en Supabase),
  es **pérdida de acceso** hasta que vuelva a haber un build con el canal. Hoy no afecta a nadie —el
  compilado está en `false`— y pasa a ser el riesgo principal del rollback **desde 2.1**.
- **Los change tokens de CKSyncEngine** ya descartados en un device: CloudKit no reenvía lo que cree
  entregado. Lo cura `resetLocalGroupsSyncState()`, no el revert.

---

## 3 · Antes y después de la Fase 3

| | Antes de la Fase 3 | Después |
|---|---|---|
| **Mecanismo** | flag remoto `groupsBackendEnabled` → OFF | revertir el build + release por TestFlight |
| **Tiempo** | segundos | horas o días (incluye revisión de App Store si es release pública) |
| **Alcance** | inmediato, por device | ~40 ficheros + 4 `.ckdb` + re-deploy de schema a CloudKit Production |
| **¿Sirve de hotfix?** | sí | **no** |

**El flag remoto sigue existiendo después de la Fase 3, pero deja de ser un rollback.** Su único uso
pasa a ser apagar el canal backend **a sabiendas de que Grupos queda inoperativo** — contención, no
vuelta atrás. Documentado así a propósito: leerlo como rollback es el error que este runbook previene.

---

## 4 · Punto de no retorno

La Fase 3 es **caro** de revertir; la **Fase 4** (schema y entitlements) es **irreversible**: toca los
`.ckdb` y el schema de CloudKit Production, que no tienen vuelta atrás por git. ⇒ **el último momento
para decidir un rollback barato es antes de la Fase 4**, y la Fase 3 «se puede parar aquí» es el estado
final útil según el plan.

---

## 5 · Mantenimiento

- Los commits de la **Fase 3** se anotan en el §1 **en el mismo commit que los crea**.
- Si aparece una acción de infraestructura nueva (deploy, SQL a mano, migración), va al **§2** en el
  turno en que se ejecuta. Ese es el apartado que se queda obsoleto en silencio.
- Cuando se encienda `groupsBackendCompiledDefault` en 2.1, **borrar el §0**: dejará de ser cierto y es
  lo primero que alguien leerá en una emergencia.
