---
id: import-of-ten-thousand-rows-still-blocks-the-main-thread
status: backlog
priority: low
area: "import, performance"
created: 2026-11-22
updated: 2026-11-22
source: "lote 1 de Importar registros (2026-11-22), medición de `import-runs-twice-on-the-main-thread`"
---

# Importar 10.000 filas sigue parando la pantalla ~10 s

## Qué ve el usuario

Con 3.000 filas el import ya no se nota (vista previa 0,3 s, importar 1,4 s). Con 10.000, la vista previa tarda 0,8 s pero
«Importar» deja la pantalla quieta ~10 s.

## Evidencia (medido)

`ImportarLote1MedicionTests`, simulador: insertar 10.000 cuesta 10,6 s y guardar 1,1 s; 3.000 cuestan 1,1 + 0,3 s. Crece
más que lineal (inferido: la misma familia que `deleting-thousands-of-records-saves-slower-than-linear`, relaciones inversas
a-muchos al asignar cuenta, categoría y etiquetas).

## Por qué no se partió en tandas

El import inserta y guarda en el contexto principal sin suspenderse a propósito: el `rollback()` de un fallo solo puede
llevarse lo del import si nadie más escribe en medio, y un guardado ajeno a mitad (el motor de la nube guarda sus páginas)
dejaría medio import guardado. Partirlo exige un contexto propio para el import, un patrón que hoy no usa ningún servicio.

## Criterio de hecho

- [ ] Medido en el iPhone 14 con 10.000 filas.
- [ ] Decidido si el caso lo justifica (el caso real de la auditoría tenía 2.749 filas).
