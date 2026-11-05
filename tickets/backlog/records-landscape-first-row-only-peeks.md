---
id: records-landscape-first-row-only-peeks
status: backlog
priority: low
area: records
created: 2026-11-02
updated: 2026-11-05
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

## 2026-11-05 · en el iPhone SE ni asoma (lote T3)

Medido en `YalaLane-Adapt-iPhone-SE` (iOS 27.2) con el mismo caso: girado, la ventana mide 375 pt de alto y la primera
fila empieza en y=319, **8 pt por debajo** de la barra de pestañas (y=311): queda entera tapada. En el 17 Pro asoma 20 pt.

Decisión de Jürgen ese día (por el bot, opción B): **se queda así**, se baja con el dedo. El caso exige que asome solo donde
cabe (17 Pro, Pro Max) y en el SE se salta citando este ticket (`XCTSkipIf` con la ventana por debajo de 390 pt). Si se
decide compactar la fila de acciones con poco alto, ese salto se quita y el caso vuelve a medir el SE.
