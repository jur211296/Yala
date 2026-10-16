// reloj.c — la hora de pared que ve la app del simulador, desplazada YALA_RELOJ_DESFASE segundos.
//
// Las capturas de la ficha citan cifras que dependen del día (lo gastado en el mes, «19 días restantes», «Teléfono en
// 2 días»). La semilla y la app las calculan con el reloj, así que el molde lanza la app creyendo que es el 13-oct-2026
// a las 9:41 (`lanzar.sh` calcula el desfase) y las capturas salen iguales se hagan el día que se hagan.
// Solo toca la app del simulador: se inyecta con SIMCTL_CHILD_DYLD_INSERT_LIBRARIES y no está en el binario de Yala.
// Compilar: `reloj/compilar.sh` (lo llama `lanzar.sh` si falta).
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <CoreFoundation/CoreFoundation.h>

static double desfase(void) {
    static int listo = 0; static double d = 0;
    if (!listo) { const char *s = getenv("YALA_RELOJ_DESFASE"); d = s ? atof(s) : 0; listo = 1; }
    return d;
}
static int r_gettimeofday(struct timeval *tv, void *tz) {
    int r = gettimeofday(tv, tz);
    if (r == 0 && tv) { double t = tv->tv_sec + tv->tv_usec / 1e6 + desfase(); tv->tv_sec = (time_t)t; tv->tv_usec = (suseconds_t)((t - (double)tv->tv_sec) * 1e6); }
    return r;
}
static int r_clock_gettime(clockid_t id, struct timespec *ts) {
    int r = clock_gettime(id, ts);
    if (r == 0 && ts && id == CLOCK_REALTIME) { int64_t ns = (int64_t)ts->tv_sec * 1000000000LL + ts->tv_nsec + (int64_t)(desfase() * 1e9); ts->tv_sec = ns / 1000000000LL; ts->tv_nsec = ns % 1000000000LL; }
    return r;
}
static uint64_t r_clock_gettime_nsec_np(clockid_t id) {
    uint64_t v = clock_gettime_nsec_np(id);
    if (id == CLOCK_REALTIME) v = (uint64_t)((int64_t)v + (int64_t)(desfase() * 1e9));
    return v;
}
static time_t r_time(time_t *t) { time_t v = time(NULL) + (time_t)desfase(); if (t) *t = v; return v; }
static CFAbsoluteTime r_CFAbsoluteTimeGetCurrent(void) { return CFAbsoluteTimeGetCurrent() + desfase(); }

#define INTERPONE(nuevo, viejo) __attribute__((used)) static struct { const void *n; const void *v; } _i_##viejo \
    __attribute__((section("__DATA,__interpose"))) = { (const void *)&nuevo, (const void *)&viejo };
INTERPONE(r_gettimeofday, gettimeofday)
INTERPONE(r_clock_gettime, clock_gettime)
INTERPONE(r_clock_gettime_nsec_np, clock_gettime_nsec_np)
INTERPONE(r_time, time)
INTERPONE(r_CFAbsoluteTimeGetCurrent, CFAbsoluteTimeGetCurrent)
