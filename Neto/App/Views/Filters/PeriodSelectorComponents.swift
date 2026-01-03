import SwiftUI

// MARK: - Equatable Period Selectors
// Extracted to prevent view re-evaluation during async data updates

struct TrendsPeriodMenu: View, Equatable {
    let selectedPeriod: DetailPeriod
    let onSelect: (DetailPeriod) -> Void

    static func == (lhs: TrendsPeriodMenu, rhs: TrendsPeriodMenu) -> Bool {
        lhs.selectedPeriod == rhs.selectedPeriod
    }

    var body: some View {
        Menu {
            ForEach(DetailPeriod.allCases) { period in
                Button {
                    onSelect(period)
                } label: {
                    HStack {
                        Text(period.rawValue)
                        if selectedPeriod == period {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            PeriodSelectorLabel(title: selectedPeriod.rawValue)
        }
        .transaction { $0.animation = nil }
        .id(selectedPeriod)
    }
}
