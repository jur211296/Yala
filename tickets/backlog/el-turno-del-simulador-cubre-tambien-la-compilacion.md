---
id: el-turno-del-simulador-cubre-tambien-la-compilacion
status: backlog
priority: very-low
area: qa
created: 2026-09-12
updated: 2026-09-12
source: lente adversarial de la sesión de la cola del simulador (2026-09-12)
---

# El turno del simulador se toma para compilar, y durante ese rato el simulador está parado

## El hecho

`qa/scripts/sim-lock.sh` envuelve el `xcodebuild … test` **entero**, y `xcodebuild test` compila
antes de correr. O sea que el turno del simulador se ocupa también durante la compilación, que es
justo el tramo en el que el simulador no hace nada.

Con dos o tres sesiones no se nota. Con catorce worktrees y una cola de tres o cuatro, cada turno
regala esos minutos a todos los que esperan.

En el `/gate` el efecto es pequeño porque el paso 1 ya compiló las dos schemes, así que el `test`
del paso 3 recompila poco. Donde sí puede doler es en una corrida desde frío o tras cambiar de rama.

## El arreglo, cuando toque

Partir el tramo:

```bash
xcodebuild build-for-testing …                       # fuera del turno
bash qa/scripts/sim-lock.sh -- \
  xcodebuild test-without-building …                 # dentro
```

Eso deja dentro del turno solo lo que de verdad usa el simulador (instalar, lanzar, correr). La
medición del 12-sep se hizo así y las dos corridas de 2 casos duraron 53,6 s y 42,7 s.

**Por qué no se hizo ya**: cambiar cómo compila el gate es más que poner una cola, y el encargo
pedía la cola. Además `build-for-testing` + `test-without-building` introduce su propia trampa —el
producto compilado tiene que ser el de tu árbol, y con catorce worktrees compartiendo DerivedData
conviene comprobarlo— que merece medirse aparte.

## Qué NO es este ticket

No es «la cola va lenta». La cola funciona y está medida. Es «la cola podría ser más corta sin
perder nada».

## Relacionados

- [[diez-worktrees-comparten-un-simulador]] — la cola y su medición
