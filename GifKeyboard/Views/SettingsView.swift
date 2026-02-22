import SwiftUI
import UIKit

struct SettingsView: View {
    @State private var currentIcon: AppIconOption = .default

    var body: some View {
        NavigationStack {
            List {
                Section("App Icon") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80))],
                        spacing: 16
                    ) {
                        ForEach(AppIconOption.allCases, id: \.self) { option in
                            IconCell(option: option, isSelected: currentIcon == option) {
                                setIcon(option)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadCurrentIcon() }
        }
    }

    private func loadCurrentIcon() {
        let name = UIApplication.shared.alternateIconName
        currentIcon = AppIconOption.allCases.first { $0.alternateIconName == name } ?? .default
    }

    private func setIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            if error == nil {
                Task { @MainActor in
                    self.currentIcon = option
                }
            }
        }
    }
}

private struct IconCell: View {
    let option: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    iconImage
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 13))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, .blue)
                            .offset(x: 4, y: 4)
                    }
                }
                Text(option.displayName)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconImage: some View {
        if let uiImage = UIImage(named: option.rawValue) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.gray.opacity(0.3))
        }
    }
}
