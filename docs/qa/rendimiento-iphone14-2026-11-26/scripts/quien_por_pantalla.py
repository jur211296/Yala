import csv, sys
from collections import Counter, defaultdict
tp, t0_ms, evp = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3]
path = tp
exec(open(sys.argv[0].rsplit('/', 1)[0] + '/perfil_lector.py').read())
ev = list(csv.DictReader(open(evp)))
T = lambda e: (int(e['epoch_ms']) - t0_ms) / 1000
win = defaultdict(list)
for i, e in enumerate(ev):
    if e['evento'] == 'scroll_inicio':
        win[e['pantalla']].append((T(e) - 2.5, T(ev[i + 1])))  # incluye la llegada a la pantalla
CLAVES = ['PanelViewModel.performCalculation()', 'PanelViewModel.loadData', 'PanelViewModel.fetchTransactionsInSlices', 'SpotlightIndexService.reconcile',
          'DetailContainerViewModel.loadData', 'DetailContainerView', 'StatisticsViewModel', 'StatisticsRecalculation', 'RecordsViewModel', 'RecordsTabView', 'RecordsSharedList',
          'GroupsViewModel', 'ScheduledPaymentsViewModel', 'BudgetsViewModel', 'InboxViewModel', 'InboxView', 'CashFlow', 'FinancialReport', 'TrendChartView.body',
          'ViewGraphDisplayLink.displayLinkTimer', 'WidgetDataCache', 'TrendsTabView', 'CategoriesTabView', 'Sankey', 'InsightsTabView', 'StatsMoneyToday', 'HeroBuckets', 'FinancialScoreCalculator']
for p, vs in win.items():
    sel = [s for s in samples if s[1] and any(a <= s[0] < b for a, b in vs)]
    dur = sum(b - a for a, b in vs)
    c = Counter()
    for _, _, st in sel:
        names = {n for n, b in st}
        for k in CLAVES:
            if any(k in n for n in names):
                c[k] += 1
    print(f"\n{p}: {dur:.0f} s, hilo ppal {len(sel)/dur/10:.0f}%")
    for k, v in c.most_common(7):
        print(f"   {100*v/max(len(sel),1):5.1f}%  {k}")
