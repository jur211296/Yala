---
id: records-landscape-first-row-only-peeks
status: backlog
priority: low
area: records
created: 2026-11-02
updated: 2026-11-02
source: "gate del encargo 2026-11-02-grupos-b-cabos-sueltos (card 97gc), IPhoneLandscapeUITests"
---

# En el iPhone girado, la primera fila de Registros solo asoma bajo la fila de acciones

Desde la card 97gc (decisión de Jürgen del 2-nov) la página Registros es igual que Estadísticas › Registros: la fila
«Nuevo registro · Voz · Foto · Yala IA» va bajo la cabecera y no hay flotante. Con el iPhone 17 Pro girado (402 pt de alto)
la primera fila empieza 20 pt por encima de la barra de pestañas y su centro queda debajo (medido en
`IPhoneLandscapeUITests.test_shortHeight_recordsHeaderLeavesTheFirstRowInView`, que antes exigía el centro a la vista y
desde ese día exige que asome). Con poco alto la cabecera ya se compacta (`SummaryHeaderStack`); la fila de acciones no.

Qué decidir: si con poco alto la fila de acciones se compacta o comparte línea con el selector Lista | Calendario, o si se
queda así porque se baja con el dedo. Sin medir cómo queda Estadísticas › Registros girado, que lleva además la barra de
chips.
