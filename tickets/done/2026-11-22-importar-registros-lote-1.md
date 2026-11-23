---
id: 2026-11-22-importar-registros-lote-1
status: done
priority: medium
area: "import"
created: 2026-11-22
updated: 2026-11-22
source: "encargo del 22-nov (Jürgen pidió encolar lo pendiente del backlog que estuviera claro)"
---

# Importar registros, lote 1

Seis tickets de la auditoría del import 2.2 en una sesión. Los seis seguían vigentes en `origin/2.3`:

- `import-has-no-duplicate-detection` (H11): reimportar el mismo archivo ya no duplica; la vista previa lo dice.
- `import-cannot-be-undone` (H12): «Deshacer importación» durante 24 h.
- `import-guesses-date-order-per-row` (H10): orden día/mes por archivo, años de dos cifras, mediodía local.
- `import-runs-twice-on-the-main-thread` (H14): medido antes y después; la vista previa no inserta y el import reutiliza.
- `import-transfer-pairing-ignores-accounts-and-currency-changes` (H9): emparejado por cuenta y con cambio de moneda.
- `import-of-thousands-of-rows-in-cloud-mode-is-unmeasured` (H15): medido contra staging.

Nuevos por lo medido: `deleting-thousands-of-records-saves-slower-than-linear`,
`import-of-ten-thousand-rows-still-blocks-the-main-thread`, `cloud-upload-of-thousands-of-rows-takes-minutes`.

Device-QA: no hace falta para cerrar; lo que pide el teléfono (tiempos en el iPhone 14) va en los tickets nuevos.
