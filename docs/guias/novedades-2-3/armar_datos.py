import json,sys,base64,os
S=sys.argv[1]
items=json.load(open(f"{S}/items_all.json"))
NUEVA="Solo se ve en una instalación nueva. Míralo en el iPhone 14 de pruebas (o en otro teléfono con TestFlight): no borres Yala en tu teléfono personal."
# --- añadir PR 824 (faltaba)
items += [
 {"pr":824,"titulo":"Gastos hormiga: cuánto suman tus compras pequeñas","area":"Estadísticas","seccion":"existente","tipo":"funcion",
  "ruta":"Estadísticas › Resumen › Detalle › tarjeta «Gastos hormiga» (debajo de Suscripciones)",
  "que_cambio":"Tarjeta nueva con lo que suman las compras pequeñas que repites, en cuántas compras, las tres que más pesan («Bus · 406 veces · S/ 6,956») y, si el período es más largo que un mes, cuánto es al mes. Al pie dice la regla con su cifra.",
  "por_que":"Ves de un vistazo la fuga de dinero que no notas compra a compra.","estado":"listo","activar":"","pro":False,
  "como_probar":"Abre Estadísticas › Resumen y baja hasta Suscripciones; prueba «Este mes» y «Todo el tiempo»."},
 {"pr":824,"titulo":"Logos de tus suscripciones en Pagos planificados","area":"Planificación","seccion":"existente","tipo":"funcion",
  "ruta":"Planificación › Pagos planificados › + › escribe «Netflix»",
  "que_cambio":"Al escribir un servicio conocido (Netflix, Spotify, Disney+, iCloud+… 40 en total) el editor propone su distintivo: iniciales sobre su color de marca. La fila nueva «Logo» deja cambiarlo, quitarlo o volver al automático. Se ve en la lista, la línea de tiempo y el calendario; los pagos de antes con nombre conocido lo muestran solos.",
  "por_que":"Reconoces cada suscripción sin leer el nombre.","estado":"listo","activar":"","pro":False,
  "como_probar":"Mira tus pagos planificados de siempre: los conocidos ya traen su logo. Crea uno «Spotify» y cambia el logo."},
 {"pr":824,"titulo":"Al registrar, Yala sugiere descripciones que ya usaste","area":"Nuevo registro","seccion":"existente","tipo":"funcion",
  "ruta":"+ › Nuevo registro › campo de descripción",
  "que_cambio":"Desde 2 letras aparecen hasta 5 descripciones que ya usaste, del mismo tipo (gasto o ingreso). Tocar una pone el texto exacto.",
  "por_que":"Escribes menos y tus registros quedan con el mismo nombre de siempre.","estado":"listo","activar":"","pro":False,
  "como_probar":"Escribe dos letras de algo habitual («de», «ca») y toca una sugerencia."},
]
fix={}
for x in items:
    p=x["pr"]; t=x["titulo"]
    if p==817:
        x["estado"]="listo"; x["activar"]=""
        x["que_cambio"]+=" Medido hoy: el servicio de producción ya lee recibos. Mientras no llegue el cupo propio de Grupos, cada recibo gasta tu prueba de foto o voz de personal."
    if p==833 and "hormiga" in t.lower():
        x["estado"]="listo"; x["activar"]=""; x["pro"]=True
        x["que_cambio"]+=" Medido hoy: el servicio de producción ya tiene esta función."
    if p==770:
        x["que_cambio"]+=" El servicio de producción ya entiende el medio de pago, también con varios movimientos en una frase."
    if p in (788,):
        x["estado"]="activable"
        x["activar"]=("1. Ajustes › Dónde viven tus datos debe decir «En tu cuenta de Yala» (la fila solo sale con tus datos en la nube y la sesión abierta). "
          "2. Ajustes › Correo del banco: copia tu dirección auto+…@yalainbox.com. "
          "3. En tu correo, crea un filtro que reenvíe los avisos de tu banco a esa dirección (la pantalla trae la guía). "
          "4. Haz un pago pequeño: en unos minutos el borrador llega a la Bandeja. "
          "Medido hoy: el servicio de producción ya tiene el correo y el dominio yalainbox.com recibe correo. No pude comprobar la última pieza del buzón, que activa Dan: si la dirección no aparece o el borrador no llega, márcalo como bug.")
    if p==945:
        x["estado"]="activable"; x["activar"]="Se activa con el ítem «Correo del banco» de Integraciones."
    if p==942 and "correo automático" in t.lower():
        x["_drop"]=True   # lo reemplaza el paso 7 de PR 951
    if p==951:
        x["estado"]="listo"; x["activar"]=NUEVA+" Además pide tu cuenta de Yala."
    if x["seccion"]=="nuevo" and x["estado"]=="activable":
        x["estado"]="listo"; x["activar"]=NUEVA
    if p==902 and "día 1" in t:
        x["estado"]="listo"; x["como_probar"]="Solo se ve los días 1 y 2 del mes; espera al 1 de diciembre (o cambia la fecha del iPhone y vuelve a la automática)."; x["activar"]=""
items=[x for x in items if not x.get("_drop")]
# --- fuera del build
fuera=[
 (930,"Nube e iCloud","Al pasar tus datos a la nube, el cifrado y las fotos se ven de entrada","Ajustes › Dónde viven tus datos › pasar a tu cuenta de Yala","La hoja de antes de activar muestra a la vista que Yala puede ver tus datos (sin cifrado de extremo a extremo), que las fotos de recibos no viajan y la opción de exportar antes. Desaparece «Ver los detalles».","Mergeado el 15-nov después de cortar el build: llega en la próxima build de TestFlight."),
 (910,"Nube e iCloud","«Volver a tu iCloud» y «Activar sin borrar» en una hoja que dice la verdad","Ajustes › Dónde viven tus datos","Volver a tu iCloud abre una hoja en tres fases (qué pasa con cada cosa, qué hacer con lo que ya hay en tu iCloud con su cifra, y confirmar). Activar la nube con un borrado pendiente explica cada caso.","Mergeado el 15-nov después de cortar el build: llega en la próxima build."),
 (988,"Integraciones","Yala web: Grupos reconoce a los mismos miembros que la app","Yala web (staging)","La web ya no dice «Todo saldado» con deudas ni «Sin nombre», y en el móvil la página ya no se amplía sola al tocar un campo.","Es de Yala web, que sigue en staging; no está en la app."),
 (943,"Ajustes y Pro","VoiceOver nombra los cinco selectores que no tenían nombre","Filtros de Registros, reparto, saldar, flujo de caja y color","Los selectores se leen con su nombre.","PR abierto, en cola de desbloqueo: no está en 2.3 todavía."),
 (924,"Estadísticas","Tendencias dice contra qué compara y VoiceOver lee las gráficas con cifras","Estadísticas › Tendencias","Comparación explícita y lectura de gráficas con números.","PR abierto, en cola de desbloqueo."),
 (922,"Registros","El calendario de Registros se pliega a la semana del día","Registros › calendario","Calendario plegado a la semana y sin apretarse en iPad.","PR abierto, en cola de desbloqueo."),
 (920,"Nuevo registro","Categorías a un toque y un buscador que entiende «café»","+ › Nuevo registro › categoría","Categorías recientes y búsqueda por palabras parecidas.","PR abierto, en cola de desbloqueo."),
 (916,"Nube e iCloud","«Cambiar de cuenta» en una fila, con cada consecuencia","Ajustes › Dónde viven tus datos","Cambiar de cuenta en una sola fila y la hoja de soltar que explica cada consecuencia.","PR abierto, en cola de desbloqueo."),
 (912,"Panel","Nota de salud honesta sin desanimar (lote 1)","Panel › nota de salud","Ajustes al texto y la lógica de la nota de salud.","PR abierto, en cola de desbloqueo."),
 (899,"Ajustes y Pro","Archivar una cuenta la saca del saldo y conserva su historial","Ajustes › Cuentas","Archivar cuentas sin perder historial.","PR abierto, en cola de desbloqueo."),
 (894,"Grupos","Pagos de grupo que no se duplican y reparto que no pierde dígitos","Grupos","Arreglos de duplicados, dígitos del reparto y cambios que preguntan antes.","PR abierto, en cola de desbloqueo."),
 (818,"Integraciones","Tu IA registra en Yala: Claude, ChatGPT y Grok dejan borradores en la Bandeja","Bandeja","Tus asistentes de IA crean borradores en tu Bandeja.","PR abierto y bloqueado: no está en 2.3."),
 (613,"Integraciones","«Conectar Gmail» para leer los correos del banco","Ajustes","Conexión mínima con Gmail, pendiente de la verificación de Google.","Borrador, no se mergea hasta que Google apruebe."),
 (984,"Integraciones","Yala web a producción (app.yala-app.pe)","Navegador","Toda la web en producción con su dominio.","Borrador: espera el arreglo de Grupos en la web y los pasos de Dan."),
 (983,"Planificación","«Crear un recurrente a partir de un registro»","Menú y detalle de un registro, Bandeja y Recurrentes","Decidido el 15-nov: crear un pago recurrente desde un registro que ya existe.","Solo decidido; lo construye un lote aparte."),
]
for pr,area,tit,ruta,qc,motivo in fuera:
    items.append({"pr":pr,"titulo":tit,"area":area,"seccion":"fuera","tipo":"funcion","ruta":ruta,"que_cambio":qc,"por_que":"","estado":"fuera","activar":motivo,"pro":False,"como_probar":""})
# ids
cnt={}
for x in items:
    cnt[x["pr"]]=cnt.get(x["pr"],0)+1; x["id"]=f'{x["pr"]}-{cnt[x["pr"]]}'
    for k in list(x):
        if k.startswith("_"): del x[k]
# orden usuario nuevo
orden_nuevo=["Bienvenida 2.3: logo","Bienvenida como vitrina","«Dividir gastos con amigos» siempre","Alta en tres preguntas","Google: «Usar otra cuenta»","Apple: «Usar otra cuenta»","Entrar con Google/Apple con datos","Recuperar desde iCloud","Restaurar con iCloud Drive","Quien trae sus datos","Puerta de Grupos sin iCloud","Entrada a Grupos desde la bienvenida","Entrar por «Dividir gastos","Entrar a una cuenta con grupos","Cerrar Yala en «Conectando","«Empezar» entra en la app","Cancelar la entrada","Bienvenida: volver atrás","El consentimiento de la nube","Tras «¡Tu cuenta está lista!»","Instalación nueva: pestañas","«Primeros pasos» como mazo","Primeros pasos: los 7 pasos","Paso 1","Paso 2","Paso 3","Paso 4","Paso 5","Armado del plan","Primeros pasos: mini tutorial","Paso 7","Final con prueba","«Tu saldo se mueve solo»","«Días después»"]
def ordn(x):
    for i,p in enumerate(orden_nuevo):
        if x["titulo"].startswith(p): return i
    return 99
for x in items:
    x["orden"]=ordn(x) if x["seccion"]=="nuevo" else 0
imgs={"826-1":"P2-G01-ojo-panel-oculto","835-1":"P2-G04-panel-ver-proyectado","843-1":"P2-G08-tendencias-proyectado-con-plan",
 "824-1":"P2-G09-gastos-hormiga-este-mes","824-2":"P2-G16-logo-en-lista","824-3":"P2-F01-sugerencias-de-descripcion",
 "770-1":"F01-yala-ia-25-almuerzo-yape","769-1":"G01-cupo-diario-antes","812-1":"P3-G05-presupuesto-lista-en-el-limite",
 "835-2":"P2-G21-widget-saldo-mostrar-proyectado","855-1":"P2-F03-moneda-dicha-con-palabras","969-1":"N01-grupos-ia-reparto-correcto"}
# imágenes por título para los que no sé el índice
bytitle={"«Primeros pasos» como mazo":"D03-los-7-pasos-enteros","Alta en tres preguntas":"C01-como-empiezas","Bienvenida como vitrina":"A01-google-ya-tienes-una-cuenta","Dos nombres fijos":"H01-donde-viven-cuenta-nueva"}
for x in items:
    f=imgs.get(x["id"])
    for k,v in bytitle.items():
        if x["titulo"].startswith(k): f=v
    if f and os.path.exists(f"{S}/img/{f}.jpg"):
        x["img"]="data:image/jpeg;base64,"+base64.b64encode(open(f"{S}/img/{f}.jpg","rb").read()).decode()
json.dump(items,open(f"{S}/data_final.json","w"),ensure_ascii=False)
from collections import Counter
print(len(items),Counter(x["seccion"] for x in items),Counter(x["estado"] for x in items))
for i,v in imgs.items():
    m=[x for x in items if x["id"]==i]; print(i, m[0]["titulo"][:60] if m else "??")
print([x["titulo"][:40] for x in items if x["seccion"]=="nuevo" and x["orden"]==99])
