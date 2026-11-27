import sys
F=sys.argv[1]
p=F+"/Yala/App/Views/Panel/PanelView.swift"; s=open(p).read()
old="""                    comprobar: {
                        viewModel.reloadOnAppearIfStale()"""
assert s.count(old)==1
s=s.replace(old,"""                    comprobar: {
                        if UserDefaults.standard.bool(forKey: "perfTempRecargaAlVolver") { viewModel.reloadAndRecalculate() } else { viewModel.reloadOnAppearIfStale() }""")
open(p,"w").write(s)
p=F+"/Yala/App/AppBootstrapper.swift"; s=open(p).read()
old="if SpotlightAlVolver.debeReconciliar(ahora: SpotlightIndexService.currentFirma()) {"
assert s.count(old)==1
s=s.replace(old,'if UserDefaults.standard.bool(forKey: "perfTempRecargaAlVolver") || SpotlightAlVolver.debeReconciliar(ahora: SpotlightIndexService.currentFirma()) {')
open(p,"w").write(s)
print("ok")
