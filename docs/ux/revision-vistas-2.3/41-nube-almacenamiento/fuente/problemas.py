"""Los problemas de la zona 41, en orden de prioridad (el número sigue el caso guía)."""
from problemas_a import PROBLEMAS_A
from problemas_b import PROBLEMAS_B
from problemas_c import PROBLEMAS_C
from problemas_d import PROBLEMAS_D
from problemas_e import PROBLEMAS_E

PROBLEMAS = sorted(PROBLEMAS_A + PROBLEMAS_B + PROBLEMAS_C + PROBLEMAS_D + PROBLEMAS_E, key=lambda p: p["num"])
EXTRA_PROBLEMAS_CSS = ""
