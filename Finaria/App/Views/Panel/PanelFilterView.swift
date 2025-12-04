import SwiftUI

struct PanelFilterView: View {
    @Bindable var viewModel: PanelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                // Fondo gris claro tipo “segmented control” iOS
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .systemGray5))

                HStack(spacing: 0) {
                    periodSegmentButton(title: "Esta semana", type: .thisWeek)
                    periodSegmentButton(title: "Este mes", type: .thisMonth)
                    periodSegmentButton(title: "Este año", type: .thisYear)
                    periodCustomSegmentButton()
                }
                .padding(2)
            }
            .frame(height: 32)
        }
    }

    private func periodSegmentButton(
        title: String,
        type: PanelPeriodType
    ) -> some View {
        let isSelected = viewModel.panelPeriodType == type

        return Button {
            viewModel.panelPeriodType = type
        } label: {
            Text(title)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                } else {
                    Color.clear
                }
            }
        )
        .foregroundStyle(isSelected ? Color.black : Color.primary)
    }

    private func periodCustomSegmentButton() -> some View {
        let isSelected = viewModel.panelPeriodType == .custom

        return Button {
            viewModel.prepareCustomPeriodDraft()
            viewModel.isPresentingCustomPeriodSheet = true
        } label: {
            Text("Personalizado")
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                } else {
                    Color.clear
                }
            }
        )
        .foregroundStyle(isSelected ? Color.black : Color.primary)
    }
}
