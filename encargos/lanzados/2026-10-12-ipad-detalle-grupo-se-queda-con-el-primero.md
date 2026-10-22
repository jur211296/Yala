# En iPad, al cambiar de grupo el detalle se queda con el primero

Card «En iPad, al cambiar de grupo el detalle se queda con el primero». Effort high. Cierre: cierra sola con PR a 2.1 (auto-merge con CI verde).

## Contexto
Ticket `tickets/backlog/ipad-group-detail-keeps-the-first-group-after-switching.md` (medido en el PR #471): en iPad, lista + detalle, al tocar otro grupo cambia el título pero gastos, «Te deben», balances y miembros siguen siendo del primero. Causa probable: `GroupsContainerView` con `.navigationDestination(item:)` que reutiliza el detalle sin re-identificarlo. Reproducible con la semilla `-uitest-seed ficha-mx` (Viaje a Oaxaca → Depa Roma Norte). En iPhone no pasa.

## Qué se pide
1. Confirmar la causa y arreglarla de forma robusta (el detalle se ata a la identidad del grupo seleccionado; su ViewModel/estado se recrea o se recarga al cambiar). Revisa si otros pares lista+detalle de la app tienen el mismo patrón y dilo en el PR (arreglar solo si es el mismo fallo y trivial).
2. Test: XCUITest en iPad (iPad Pro 13" M5) con `ficha-mx` que abre un grupo, cambia a otro y comprueba título, miembros y saldo del segundo; rojo antes / verde después. Unit test de la lógica si la hay.
3. Capturas antes/después en iPad en `~/Claude/worktrees/_capturas/<fecha>-ipad-detalle-grupo-se-queda-con-el-primero/`.
4. Ticket a in qa/done en el mismo PR.

## Qué NO tocar
La semilla `grupos` (la usan otros XCUITest), backend, Vercel. Sin deploy.

## SIMULADORES iOS EN LA MINI
Nunca más de un simulador encendido a la vez; al terminar (y antes de cerrar) `xcrun simctl shutdown all`. NO usar el simulador entre 9:00 y 11:00 Lima (franja de Lola). `nice -n 10 xcodebuild -jobs 2`, carga < 8. Tests con -only-testing, no suites enteras sin necesidad.

## PR a 2.1
`git fetch origin && git rebase origin/2.1` antes de abrir. Un PR, en lenguaje de usuario, con device-QA para Jürgen en iPad.

## Cómo se sabe
En iPad, cambiar de grupo muestra el contenido del grupo nuevo; test rojo→verde; capturas; CI verde.

## Paso 0 (Frank, 2026-10-12 18:50 Lima)

- **Causa (leída en el código, a confirmar con el rojo):** `GroupDetailView` guarda su `GroupDetailViewModel`, la pestaña elegida y `wasArchivedOnAppear` en `@State` iniciado en el `init`; en la columna de detalle SwiftUI reutiliza la vista al cambiar `selectedGroup` y esos `@State` no se reinician. Registros ya resuelve lo mismo con `.id(record.persistentModelID)`.
- **Arreglo:** `.id(group.persistentModelID)` sobre el detalle en el `navigationDestination(item:)`, por fuera de `announcesShownInDetailColumn()` para que el aviso de «se abrió algo» también se repita (lista superpuesta en iPad mini). Mismo molde que Registros; sin tocar `GroupDetailView`.
- **Test:** caso nuevo en `AdaptiveNavigationUITests`, semilla `ficha-mx`. En ancho: Oaxaca → Depa, comprueba título, gasto «Renta de octubre» presente y «Mercado 20 de Noviembre» ausente, miembros (3) y saldo (5,374) por dígitos; y vuelta a Oaxaca. En compacto el mismo recorrido con el chevron (corre en el CI de iPhone).
- **Unit test:** no hay lógica nueva que probar (el arreglo es identidad de vista). Asumido.
- **Otros pares lista+detalle:** Registros ya tiene `.id`; Ajustes usa `path` con un único destino; Planificación (presupuestos, pagos programados) va por `NavigationLink(value:)` y su detalle calcula en `onAppear` → se mide en el iPad y se arregla solo si falla igual y es trivial.
