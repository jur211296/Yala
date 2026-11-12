#!/usr/bin/env python3
"""Deriva de una foto del App Group las fotos de los estados con pocos datos, para la matriz de estados de los widgets.

    python3 qa/widget-render/estados.py <foto.plist> <carpeta de salida>

Escribe un plist por estado (`completo`, `vacio`, `pocos`, `sin-ingresos`, `sin-presupuestos`, `sin-gastos`):

- completo           la foto tal cual.
- vacio              una cuenta en 0, sin movimientos, presupuestos ni pagos: alguien que acaba de empezar.
- pocos              una cuenta, dos categorías (y sus subcategorías), un presupuesto, un pago y dos movimientos.
- sin-ingresos       todo menos los ingresos (el mes aún no cobró).
- sin-presupuestos   todo menos los presupuestos.
- sin-gastos         solo ingresos: sin categorías, gasto 0 (el día 1 con el sueldo recién entrado).

Cada estado toca todos los períodos de la foto, no solo el mes, para que los widgets configurados en otro período digan
lo mismo. La foto sale de `export-snapshot.sh`; la de `fixtures/realista-*.plist` sirve de base.
"""
import copy
import json
import plistlib
import sys
from pathlib import Path


def summaries(snap):
    """Todos los resúmenes de período de la foto (los de `periodSummaries` y los dos sueltos)."""
    out = list(snap.get("periodSummaries", {}).values())
    for key in ("thisMonthSummary", "allTimeSummary"):
        if key in snap:
            out.append(snap[key])
    return out


def reweigh(items, total):
    for item in items:
        item["percentage"] = (item["amount"] / total * 100) if total else 0


def without_income(snap):
    for s in summaries(snap):
        s["totalIncome"] = 0
        s["incomeIsApproximate"] = False
        s["netCashFlow"] = -s["totalExpense"]
        for p in s.get("cashFlowPoints", []):
            p["income"] = 0
            p["net"] = -p["expense"]
        for f in s.get("accountFlows", []):
            f["income"] = 0
            f["net"] = -f["expense"]
    snap["transactions"] = [t for t in snap.get("transactions", []) if not t.get("isIncome")]
    snap["scheduledPayments"] = [p for p in snap.get("scheduledPayments", []) if not p.get("isIncome")]


def without_expenses(snap):
    for s in summaries(snap):
        s["totalExpense"] = 0
        s["expenseIsApproximate"] = False
        s["topCategories"] = []
        s["topSubcategories"] = []
        s.pop("expenseBreakdownTotal", None)
        s.pop("expenseSubcategoryBreakdownTotal", None)
        s["netCashFlow"] = s["totalIncome"]
        for p in s.get("cashFlowPoints", []):
            p["expense"] = 0
            p["net"] = p["income"]
        for f in s.get("accountFlows", []):
            f["expense"] = 0
            f["net"] = f["income"]
    incomes = [t for t in snap.get("transactions", []) if t.get("isIncome")]
    if not incomes and snap.get("transactions"):
        # La foto realista no trae ingresos entre los últimos registros: se fabrica el sueldo con el primero.
        t = copy.deepcopy(snap["transactions"][0])
        t.update(isIncome=True, amount=8500, amountInPreferredCurrency=8500, categoryName="Ingresos",
                 subcategoryName="Sueldo", categoryIcon="banknote.fill", subcategoryIcon="banknote.fill",
                 categoryColor="#00C2CB")
        incomes = [t]
    snap["transactions"] = incomes
    snap["budgets"] = [dict(b, spentAmount=0, percentUsed=0) for b in snap.get("budgets", [])]


def few(snap):
    snap["accountBalances"] = snap.get("accountBalances", [])[:1]
    if snap["accountBalances"]:
        snap["totalBalance"] = snap["accountBalances"][0]["balance"]
    for s in summaries(snap):
        cats = s.get("topCategories", [])[:2]
        names = {c["name"] for c in cats}
        subs = [x for x in s.get("topSubcategories", []) if x.get("categoryName") in names][:2]
        old = s["totalExpense"] or 1
        total = sum(c["amount"] for c in cats)
        s["topCategories"] = cats
        s["topSubcategories"] = subs
        s["expenseBreakdownTotal"] = total
        s["expenseSubcategoryBreakdownTotal"] = total
        reweigh(cats, total)
        reweigh(subs, total)
        ratio = total / old
        s["totalExpense"] = total
        for p in s.get("cashFlowPoints", []):
            p["expense"] = round(p["expense"] * ratio, 2)
            p["net"] = p["income"] - p["expense"]
        s["netCashFlow"] = s["totalIncome"] - total
        s["accountFlows"] = s.get("accountFlows", [])[:1]
        for f in s["accountFlows"]:
            f["expense"] = total
            f["net"] = f["income"] - total
    snap["budgets"] = snap.get("budgets", [])[:1]
    snap["scheduledPayments"] = snap.get("scheduledPayments", [])[:1]
    snap["transactions"] = snap.get("transactions", [])[:2]


def empty(snap):
    without_expenses(snap)
    without_income(snap)
    snap["transactions"] = []
    snap["budgets"] = []
    snap["scheduledPayments"] = []
    pm = snap.get("paymentsMonth")
    if pm:
        pm.update(paidDays=[], pendingDays=[], remainingToPay=0)
    snap["accountBalances"] = [dict(a, balance=0) for a in snap.get("accountBalances", [])[:1]]
    snap["totalBalance"] = 0
    for s in summaries(snap):
        s["periodBalance"] = 0
        s["periodBalanceIsApproximate"] = False
        s["netCashFlow"] = 0
        s["accountFlows"] = []
    for points in snap.get("trendData", {}).values():
        for p in points:
            p["balance"] = 0


STATES = {
    "completo": lambda s: None,
    "vacio": empty,
    "pocos": few,
    "sin-ingresos": without_income,
    "sin-presupuestos": lambda s: s.__setitem__("budgets", []),
    "sin-gastos": without_expenses,
}


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    base = plistlib.loads(src.read_bytes())
    for name, mutate in STATES.items():
        values = copy.deepcopy(base)
        snap = json.loads(values["widget_data_cache"])
        mutate(snap)
        values["widget_data_cache"] = json.dumps(snap).encode()
        (out / f"{name}.plist").write_bytes(plistlib.dumps(values))
        print(out / f"{name}.plist")


if __name__ == "__main__":
    main()
