#!/usr/bin/env python3
"""Genera el artefacto de la revisión por vistas 2.3.

Lee `hallazgos.tsv` (una fila por hallazgo) y `plantilla.html`, y escribe en la carpeta de arriba:
  - `index.html`: la página que se publica como artefacto de Claude.
  - `img/`: una captura por problema, sacada de la página de ese problema en
    `docs/ux/revision-vistas-2.3/<zona>/1N-*.html` (N = número del problema).

Uso: python3 build.py            (desde cualquier carpeta)
     python3 build.py --sin-img  (no regenera las capturas; necesita `sips`, del Mac)
"""
import json
import re
import subprocess
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parent
REPO = SALIDA.parents[2]
REVISION = REPO / "docs/ux/revision-vistas-2.3"
GH = "https://github.com/jur211296/Yala"
BLOB = f"{GH}/blob/2.3"
PEND = f"{BLOB}/encargos/pendientes"

ZONAS = [
    # número, slug (hash), nombre corto, nombre largo, carpeta, PRs, estado
    ("30", "panel", "Panel", "Panel: lectura del mes, cuentas, nota y gráfica", "30-panel", [846],
     "Revisada el 7-nov. Sus necesarias ya salieron en el lote de Panel."),
    ("31", "registros", "Registros", "Registros, filtros, calendario y búsqueda", "31-registros", [847],
     "Revisada el 7-nov. Sin lote: nadie consolidó todavía sus necesarias."),
    ("32", "nuevo-registro", "Nuevo registro", "Nuevo registro, favoritos, voz y foto", "32-nuevo-registro", [848],
     "Revisada el 7-nov. El lote de Formulario ya salió; sus secundarios no se clasificaron."),
    ("34", "planificacion", "Planificación", "Planificación: presupuestos y pagos planificados", "34-planificacion", [852],
     "Revisada el 7-nov y consolidada el 9-nov."),
    ("35", "estadisticas", "Estadísticas", "Estadísticas", "35-estadisticas", [853],
     "Revisada el 7-nov y consolidada el 9-nov."),
    ("36", "reportes-flujo", "Reportes y Flujo", "Reportes y Flujo de caja", "36-reportes-flujo", [859],
     "Revisada el 7-nov y consolidada el 9-nov."),
    ("37", "grupos", "Grupos", "Grupos en el uso diario", "37-grupos", [856, 857],
     "Revisada el 7-nov, con siete tickets, y consolidada el 9-nov."),
    ("38", "bandeja-ia", "Bandeja e IA", "Bandeja, Yala IA, correo del banco, Apple Pay y Siri", "38-bandeja-ia", [860],
     "Revisada el 7-nov, con tres tickets, y consolidada el 9-nov."),
    ("39", "cuentas", "Cuentas y categorías", "Cuentas, tarjetas, categorías, etiquetas y divisas", "39-cuentas-categorias", [862],
     "Revisada y consolidada el 9-nov."),
    ("40", "perfil-ajustes", "Perfil y Ajustes", "Perfil, Más, Ajustes, Pro y ayuda", "40-perfil-ajustes", [864],
     "Revisada y consolidada el 9-nov."),
    ("41", "nube", "Nube", "Dónde viven tus datos: nube, iCloud y cierre de sesión", "41-nube-almacenamiento", [865],
     "Revisada y consolidada el 9-nov. Cinco puntos de datos esperan su card de decisión."),
]

LOTES = [
    # id, título, puntos según la consolidación, estado, enlace, review adversarial
    ("P", "Panel: montos ocultos en la ayuda, texto grande y «Restablecer» que pregunta", 3, "hecho", f"{GH}/pull/854", ""),
    ("F", "Formulario: monedas claras y «Apuntarlo a mano» en el muro de Pro", 3, "hecho", f"{GH}/pull/855", ""),
    ("1", "Grupos: pagos que se duplican, dígitos que se pierden y cambios sin aviso", 5, "pendiente",
     f"{PEND}/2026-11-09-necesarias-01-grupos-dinero-y-datos.md", "todo el lote"),
    ("2", "Cifras que no cuadran: ritmo, desglose de presupuesto, día más caro y céntimo del reparto", 4, "pendiente",
     f"{PEND}/2026-11-09-necesarias-02-cifras-que-no-cuadran.md", "todo el lote"),
    ("3", "Bandeja: duplicados en el lote, borradores fuera de la lista y textos de Siri y Apple Pay", 4, "pendiente",
     f"{PEND}/2026-11-09-necesarias-03-bandeja-duplicados-y-textos.md", "el punto de duplicados"),
    ("4", "Planificación: saltar no es pagar, mes cerrado, presupuesto de un día y límite gratis", 5, "pendiente",
     f"{PEND}/2026-11-09-necesarias-04-planificacion-saltar-y-limites.md", ""),
    ("5", "Texto grande en Estadísticas, Reportes, Bandeja, Ajustes y Etiquetas", 5, "pendiente",
     f"{PEND}/2026-11-09-necesarias-05-texto-grande-pantallas-secundarias.md", ""),
    ("6", "Grupos: saldos que se contradicen y lectura con VoiceOver", 5, "pendiente",
     f"{PEND}/2026-11-09-necesarias-06-grupos-saldos-y-voiceover.md", ""),
    ("7", "Estadísticas: textos que dicen lo que no es", 5, "pendiente",
     f"{PEND}/2026-11-09-necesarias-07-estadisticas-textos.md", ""),
    ("8", "Flujo de caja: mes equivocado, «vs» sin traducir, vacío y contraste", 4, "pendiente",
     f"{PEND}/2026-11-09-necesarias-08-flujo-de-caja-mes-y-textos.md", ""),
    ("9", "Cuentas, categorías, etiquetas y divisas: lo que aparece sin pedirlo", 4, "pendiente",
     f"{PEND}/2026-11-09-necesarias-09-cuentas-categorias-etiquetas.md", ""),
    ("10", "Ajustes y Pro: textos que mandan al sitio equivocado", 3, "pendiente",
     f"{PEND}/2026-11-09-necesarias-10-ajustes-y-pro-textos.md", ""),
    ("11", "Dónde viven tus datos: textos que mandan a otra fila, cifras y texto grande", 5, "pendiente",
     f"{PEND}/2026-11-09-necesarias-11-donde-viven-tus-datos-textos-y-texto-grande.md", ""),
]

DECISIONES = [
    ("¿Cuándo entra 2.2 en 2.3?",
     "Arreglos ya hechos en 2.2 no están en 2.3 y no van en ningún lote. Si las ramas divergen, hay que portarlos a mano.",
     ["planificacion", "estadisticas", "grupos", "cuentas"]),
    ("Free ve el flujo de caja avanzado",
     "El recorte de 3 meses y el aviso de Pro nunca actúan. ¿A propósito o se cierra?", ["reportes-flujo"]),
    ("Apagar «deudas en una moneda»",
     "Cambia la moneda del grupo para todos, sin preguntar. ¿Se conserva, se pregunta o se deja?", ["grupos"]),
    ("Número de cuenta",
     "Se guarda el número completo de una tarjeta. ¿Solo cuatro dígitos, y se recorta lo guardado?", ["cuentas"]),
    ("Ajustar el saldo",
     "La opción preelegida puede reescribir todos los meses. ¿«Registro de ajuste» siempre por defecto?", ["cuentas"]),
    ("Archivar conserva el historial",
     "La opción A del 8-oct sigue sin hacer y tiene su card. ¿Cuándo entra?", ["cuentas"]),
    ("Ancho en el iPad",
     "Cuatro zonas piden ancho legible o dos columnas. ¿Un patrón común antes de tocar cada una?",
     ["estadisticas", "reportes-flujo", "grupos", "cuentas"]),
]

NOTAS = [
    ("El índice de la revisión está desactualizado",
     "Su README (PR 850 y 851) dice que las zonas 34 a 41 están pendientes. Todas se revisaron después. "
     "La consolidación lo avisa y no lo corrige.",
     f"{BLOB}/docs/ux/revision-vistas-2.3/README.md"),
    ("Registros no tiene lote",
     "La consolidación la dejó fuera. Su ficha marca como baratos B3, F1 + F3, L3, T1 y E2. Sus 15 secundarios no tienen clase.",
     f"{BLOB}/docs/ux/revision-vistas-2.3/31-registros/ficha.md"),
    ("«Beto paga a Tú» no tiene fila propia en la consolidación",
     "Está dentro del problema 1 de Grupos y tiene ticket (PR 857). El lote 6 lo incluye; aquí sale como hallazgo aparte.",
     f"{PEND}/2026-11-09-necesarias-06-grupos-saldos-y-voiceover.md"),
    ("Planificación tiene un problema 7 que su ficha no lista",
     "La revisión (página 7, texto grande en pagos) lo trae; la ficha y la tabla de la consolidación no. "
     "La consolidación lo da por arreglado en 2.2 en su primera decisión. Aquí va como «Ya en 2.2».",
     f"{BLOB}/docs/ux/revision-vistas-2.3/34-planificacion/ficha.md"),
    ("Sin contradicciones de clase",
     "Fichas y consolidación no se contradicen en la clase de ningún hallazgo. Ninguna fuente usa «descartado»: "
     "lo que no entra en un lote queda como decisión, rediseño, menor o por verificar.",
     ""),
]


def leer_hallazgos():
    filas, contador = [], {}
    for linea in (AQUI / "hallazgos.tsv").read_text(encoding="utf-8").splitlines():
        if not linea.strip() or linea.startswith("#"):
            continue
        campos = linea.split("|")
        if len(campos) != 8:
            sys.exit(f"Fila con {len(campos)} campos: {linea}")
        zona, cod, clase, sev, lote, texto, nota, ticket = campos
        if not cod:
            contador[zona] = contador.get(zona, 0) + 1
            cod = f"S{contador[zona]}"
        filas.append({"z": zona, "c": cod, "k": clase, "s": sev, "l": lote, "t": texto, "n": nota,
                      "tk": f"{BLOB}/tickets/backlog/{ticket}" if ticket else ""})
    return filas


def numero_problema(cod):
    m = re.fullmatch(r"(?:PN-|P)(\d+)", cod)
    return int(m.group(1)) if m else None


def capturas(filas, regenerar):
    """Una captura por problema: la primera de su página que no se haya usado ya en esa zona."""
    destino = SALIDA / "img"
    destino.mkdir(exist_ok=True)
    elegidas = {}
    for zona, carpeta in ((z[0], z[4]) for z in ZONAS):
        usadas = set()
        for pagina in sorted((REVISION / carpeta).glob("1[1-9]-*.html")):
            n = int(pagina.name[1])
            rutas = re.findall(r'capturas/([^"\']+\.(?:jpg|png))', pagina.read_text(encoding="utf-8"))
            # Algunas páginas (zonas 39 y 40) enlazan capturas que no están en el repo: se saltan.
            rutas = [r for r in dict.fromkeys(rutas) if (REVISION / carpeta / "capturas" / r).is_file()]
            libre = next((r for r in rutas if r not in usadas), rutas[0] if rutas else None)
            if not libre:
                continue
            usadas.add(libre)
            nombre = f"{zona}-p{n}.jpg"
            if regenerar:
                subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "62",
                                "--resampleWidth", "420", str(REVISION / carpeta / "capturas" / libre),
                                "--out", str(destino / nombre)], check=True, capture_output=True)
            elegidas[(zona, n)] = {"src": f"img/{nombre}", "pie": pagina.stem[3:].replace("-", " ")}
    for f in filas:
        n = numero_problema(f["c"])
        if n is not None and (f["z"], n) in elegidas:
            f["img"] = elegidas[(f["z"], n)]["src"]
    return elegidas


def main():
    filas = leer_hallazgos()
    elegidas = capturas(filas, "--sin-img" not in sys.argv)
    datos = {
        "zonas": [{"num": z[0], "slug": z[1], "corto": z[2], "largo": z[3], "prs": z[5], "estado": z[6],
                   "ficha": f"{BLOB}/docs/ux/revision-vistas-2.3/{z[4]}/ficha.md",
                   "fotos": [{"n": n, **v} for (zz, n), v in sorted(elegidas.items()) if zz == z[0]]}
                  for z in ZONAS],
        "lotes": [{"id": l[0], "titulo": l[1], "puntos": l[2], "estado": l[3], "url": l[4], "adv": l[5]} for l in LOTES],
        "decisiones": [{"t": d[0], "d": d[1], "z": d[2]} for d in DECISIONES],
        "notas": [{"t": n[0], "d": n[1], "u": n[2]} for n in NOTAS],
        "hallazgos": filas,
        "gh": GH,
        "consolidacion": f"{BLOB}/docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md",
    }
    js = json.dumps(datos, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    plantilla = (AQUI / "plantilla.html").read_text(encoding="utf-8")
    if "/*__DATOS__*/null" not in plantilla:
        sys.exit("La plantilla no tiene el marcador /*__DATOS__*/null")
    (SALIDA / "index.html").write_text(plantilla.replace("/*__DATOS__*/null", js), encoding="utf-8")
    print(f"{len(filas)} hallazgos · {len(elegidas)} capturas · {SALIDA / 'index.html'}")


if __name__ == "__main__":
    main()
