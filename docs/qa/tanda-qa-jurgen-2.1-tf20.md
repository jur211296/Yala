# Tanda de QA de Jürgen — 2.1, las cuatro cards del PR #577

Sale de la tanda del TestFlight 19 (20-oct): falló `t2q8` y salieron tres cards nuevas de 2.1 (`840m`, `blqa`, `z81w`).
Las cuatro las arregló el PR **#577**. Esta tanda las prueba en aparatos de verdad.

**Todo en Yala Dev contra staging.** Ninguna de las cuatro depende de algo que solo tenga producción (App Store, App
Attest en `enforce`, StoreKit): el TestFlight 20 sale para el envío, no para esta tanda. Tiempo: unos **50 min**.

## Montaje

- **Yala Dev** compilado desde `origin/2.1` con el #577 dentro e instalado por Frank con `devicectl`.
- **iPhone de QA** (iCloud `test@yala-app.pe`) = aparato **A**, el admin del grupo.
- **iPad** (iCloud `test@yala-app.pe`) = aparato **B**, el que se une. Solo tiene Yala Dev, así que los enlaces abren la
  que toca.
- **Cuentas:** staging está sin cuentas de prueba, así que `admin@yala-app.pe`, `test@yala-app.pe` y
  `jur211296@gmail.com` (Google) cuentan como nuevas.
- El contenedor de iCloud de Yala Dev de `test@` guarda el historial de la tanda del 19 (1.500 movimientos importados y
  borrados): es justo el iCloud largo que hizo fallar `blqa`.

## Orden

| # | Bloque | Card | Aparato | Min |
|---|---|---|---|---|
| 1 | iCloud privado con mucho historial | `blqa` | A | 10 |
| 2 | Abrir el enlace en una instalación nueva + puerta 1 (enlace directo) | `z81w`, `t2q8` | A + B | 10 |
| 3 | Rechazar una solicitud en un grupo de la nube | `840m` | A + B | 5 |
| 4 | Puerta 2: bienvenida › «Tengo una invitación» | `t2q8` | A + B | 10 |
| 5 | Puerta 3: cerrar Yala a mitad y volver a abrir el enlace | `t2q8` | A + B | 10 |

Cada bloque deja los aparatos como los necesita el siguiente.

---

### 1 · iCloud privado con mucho historial — `blqa` · bloquea

1. iPhone: borra Yala Dev (la reinstalo yo). **«Vengo por un grupo»** › **«Crear mi primer grupo»** › **Google
   admin@yala-app.pe** › crea **«QA unión 20»**.
2. Perfil › **«Activar Yala completo»** › **«Tu cuenta en tu iCloud privado»**. Espera aunque pase de 25 s.
3. **Esperado:** cifras de lo que hay en tu iCloud, o que está vacío. **No** sale «No pudimos conectarnos a iCloud».
4. Si sale un aviso, debe decir **«iCloud tardó demasiado en responder»**. Frank mira en la consola cuántas páginas y
   borrados recorrió.
5. **«Volver»**: el iPhone se queda solo con Grupos.

### 2 · Abrir el enlace en una instalación nueva + puerta 1 — `z81w`, `t2q8` · bloquea

1. iPhone: Grupos › «QA unión 20» › sus ajustes › **«Invitar por enlace»** › al iPad por AirDrop.
2. iPad: borra Yala Dev; la reinstalo yo **sin abrirla**.
3. Abre el enlace con el cronómetro en marcha.
4. **`z81w` · esperado:** desde el primer instante, **«Abriendo tu invitación…»** sin botones, y **«Conecta tu
   cuenta»** en 1-2 s. En ningún momento se puede tocar «Empezar».
5. **Google test@yala-app.pe** › **«Unirme al grupo»**.
6. **`t2q8` · esperado:** **no** sale «Antes de unirte, este teléfono queda en blanco»; acaba en **«Esperando
   aprobación»**.

### 3 · Rechazar una solicitud en un grupo de la nube — `840m` · bloquea

1. iPhone: Grupos › «QA unión 20» › **«Miembros»** › la solicitud de test@ › **«Rechazar»** › confirma.
2. **Esperado en el iPhone:** la solicitud desaparece, sin error.
3. **Esperado en el iPad:** llega el aviso y el grupo dice **«Solicitud rechazada»**.

### 4 · Puerta 2: bienvenida › «Tengo una invitación» — `t2q8` · bloquea

1. iPhone: «Invitar por enlace» otra vez › al iPad por AirDrop. En el iPad, si se abre Yala, ciérrala del todo.
2. iPad: borra Yala Dev; la reinstalo yo. **Ábrela tú** desde la pantalla de inicio.
3. **«Vengo por un grupo»** › **«Tengo una invitación»** › pega el enlace › **Google jur211296@gmail.com** › «Unirme al
   grupo».
4. **Esperado:** **no** pide «Abre Yala otra vez» ni dejar el teléfono en blanco; acaba en «Esperando aprobación».

### 5 · Puerta 3: cerrar Yala a mitad — `t2q8` · bloquea

1. iPhone: aprueba a jur211296 y manda un enlace nuevo al iPad.
2. iPad: borra Yala Dev; la reinstalo yo **sin abrirla**. Abre el enlace › **Google test@yala-app.pe** › «Unirme al
   grupo».
3. En **«Conectando con tu grupo…»**, cierra Yala del todo y vuelve a abrir el enlace.
4. **Esperado:** no pide dejar el teléfono en blanco ni se queda minutos en «Conectando…»; acaba en «Esperando
   aprobación».

---

## Al terminar

- Cada card que pase, a done, y su ticket de `tickets/qa/`, también.
- El iPad vuelve a tu iCloud personal.
- Staging: Frank borra las cuentas de prueba de la tanda (las `i5-*` se quedan).

---

## Resultado (2026-10-21)

**Montaje real:** el iPad Pro ya no es de Jürgen. El aparato **B** fue un **iPad Air** con iCloud `jur211296@gmail.com`.
Hubo que activarle el Modo de desarrollador y registrarlo en el perfil de Yala Dev (recompilado desde `e47b5cca9`).

**Pasan las cuatro cards:**

- `blqa`: el iCloud de test@ contesta 1 registro, 2 cuentas y 62 categorías, sin «No pudimos conectarnos». El rastro
  `ICloudScan` va al registro del sistema y no a la consola de `devicectl`: no se midió.
- `z81w`: «Abriendo tu invitación…» sale desde el primer instante y la bienvenida no se puede tocar, pero tarda **12 s**
  hasta «Conecta tu cuenta». Jürgen la cierra por la pantalla (opción A); el tiempo pasa a `apsn`.
- `840m`: el rechazo desaparece en el iPhone sin error y el iPad dice «Solicitud rechazada» (en staging, `rejected`).
- `t2q8`: las tres puertas acaban en «Esperando aprobación», sin «queda en blanco» (en staging, `pendingApproval`). Queda
  sin medir si el iCloud de jur211296 tenía datos de Yala Dev.

**Card nueva (2.2, alta):** `apsn`. En una instalación nueva, la pantalla se queda negra unos 10 s tras «Vengo por un
grupo». Lleva también los 12 s de `z81w`.
