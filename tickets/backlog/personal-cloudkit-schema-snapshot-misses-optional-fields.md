---
id: personal-cloudkit-schema-snapshot-misses-optional-fields
status: backlog
priority: high
area: "cloudkit, sync, schema"
created: 2026-10-08
updated: 2026-10-08
source: análisis de impacto de multi-currency-accounts (2026-10-08)
---

# El esquema de iCloud guardado en el repo no tiene campos opcionales que la app sí escribe

## Qué le puede pasar al usuario

Este ticket tiene dos lecturas posibles, y el repo no permite saber cuál es la buena.

**Si el snapshot es fiel:** un usuario en modo iCloud rellena el número de cuenta de una cuenta, o
guarda un favorito con importe. iCloud de producción rechaza ese registro porque no conoce el campo.
La cuenta o el favorito dejan de sincronizar con su otro dispositivo, y nadie se entera.

**Si no lo es:** no le pasa nada al usuario, pero el «contrato» del esquema que guarda el repo es falso,
y nadie puede apoyarse en él para planificar un campo nuevo.

## Lo medido (2026-10-08, árbol `e755b0d64`)

Comparé las propiedades de cada `@Model` de `Yala/Models/` con los campos de su record type en
`Cloudkit Schemas/yala-production.ckdb`. Quitando las relaciones a-muchos, que no son campos, faltan:

| Record type | Campos que el modelo tiene y el snapshot no |
|---|---|
| `CD_Account` | `accountNumber` |
| `CD_Budget` | `startDate`, `endDate`, `currentPeriodStart` |
| `CD_CashFlowLine` | `customMonthsRaw` |
| `CD_CashFlowPlan` | `startingBalanceDate` |
| `CD_ExchangeRate` | `result` |
| `CD_FavoritePayment` | `amount` |
| `CD_NotificationItem` | `weekdaysRaw` |
| `CD_ScheduledPayment` | `selectedWeekdays`, `yearlyMonth`, `yearlyDay`, `endDate`, `dates` |
| `CD_TransactionItem` | `tags` (relación a-muchos: probablemente no es un campo) |

- **Todos son opcionales.** Encaja con cómo crea campos CloudKit en Development: solo cuando se guarda
  un valor que no es `nil`. [inferido]
- Faltan en los **cuatro** snapshots personales: `yala-production`, `yala-development`,
  `yala_dev-production` y `yala_dev-development`. Medido para `CD_FavoritePayment.CD_amount`, que da 0
  en los cuatro.
- No son campos nuevos. `FavoritePayment.amount` y `Budget.startDate` existen desde
  `aa7adc70c` (2026-01-24). Los snapshots son del 2026-07-10 (`c76b5c2a8`).
- **Ningún test vigila el `.ckdb` personal**: `rg -c 'ckdb' YalaTests` da 0. El de Grupos sí tiene
  uno, `CloudKitGroupsSchemaParityTests`.
- Las propiedades de `Split*` también salen en la comparación, pero viven en el store de Grupos, que
  no se espeja a iCloud. No entran aquí.

Comando que lo reproduce, desde la raíz del repo:

```
python3 - <<'PY'
import re,glob
ck=open("Cloudkit Schemas/yala-production.ckdb").read()
types={m.group(1):set(re.findall(r'^\s+"?(CD_\w+)"?\s',m.group(2),re.M))
       for m in re.finditer(r'RECORD TYPE (CD_\w+) \((.*?)\n    \);',ck,re.S)}
for f in sorted(glob.glob("Yala/Models/*.swift")):
    s=open(f).read()
    for cm in re.finditer(r'@Model\s+(?:final\s+)?class\s+(\w+)\s*\{',s):
        body=s[cm.end():s.find("\n}\n",cm.end())]
        props=[re.search(r'var (\w+)',l).group(1) for l in body.split("\n")
               if re.match(r'\s*(@Attribute\([^)]*\)\s*)?(@Relationship\([^)]*\)\s*)?var \w+',l) and '{' not in l]
        ct="CD_"+cm.group(1)
        if ct in types:
            miss=[p for p in props if "CD_"+p not in types[ct]]
            if miss: print(ct,"sin:",miss)
PY
```

**No medido:** el esquema vivo de producción. Esta sesión no tenía acceso a la consola de iCloud, y su
encargo prohibía tocar producción.

## Precedentes que hacen creíble la primera lectura

- Incidente `isOpeningBalance` (27-jun → 1-jul): un campo nuevo sin desplegar a Production dejó el sync
  de Grupos muerto en silencio durante cuatro días.
- `CD_GroupBridgePreference` faltaba en todos los entornos con un sitio de escritura vivo en producción
  (`c76b5c2a8`).

## Criterio de hecho (AC)

- [ ] Abierto el esquema de Production de `iCloud.<contenedor personal>` en la consola de CloudKit:
      ¿existen `CD_Account.CD_accountNumber` y `CD_FavoritePayment.CD_amount`?
- [ ] Si faltan: desplegados todos los de la tabla a Production en los dos contenedores personales, y
      snapshots regenerados.
- [ ] Si existen: snapshots regenerados para que el repo diga la verdad.
- [ ] Un test de paridad del `.ckdb` personal contra los modelos, al estilo de
      `CloudKitGroupsSchemaParityTests`, para que un campo opcional no vuelva a quedarse fuera sin que
      nadie lo vea.

## Relacionados

- `multi-currency-accounts`: la opción recomendada añade un campo opcional a `CD_Account`, y este
  ticket dice por qué no basta con fiarse del snapshot
  (`docs/multi-currency-accounts-impact-2026-10.md`, secciones 2.12 y 4).
