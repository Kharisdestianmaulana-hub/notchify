import SwiftUI

// MARK: - Tab Picker Views
struct TabPickerRowView: View {
    let tab: NotchTab
    let isSelected: Bool
    let isPinned: Bool
    let canPin: Bool
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : (isHovered ? .white : .gray))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.06))
                )
            
            Text(tab.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : (isHovered ? .white : .white.opacity(0.85)))
            
            Spacer()
            
            Button(action: {
                if canPin || isPinned {
                    onTogglePin()
                }
            }) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isPinned ? Color.blue : (canPin ? (isHovered ? Color.white : Color.gray) : Color.gray.opacity(0.3)))
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isPinned && !canPin)
            .help(isPinned ? LanguageManager.tr("Unpin from bar") : (canPin ? LanguageManager.tr("Pin to bar") : LanguageManager.tr("Max 6 tabs reached")))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.12) : (isHovered ? Color.white.opacity(0.08) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { h in
            isHovered = h
        }
        .onTapGesture {
            onSelect()
        }
    }
}

struct TabPickerPopoverView: View {
    @ObservedObject var viewModel: NotchViewModel
    let pinnedTabs: [NotchTab]
    let allTabs: [NotchTab]
    let onTogglePin: (NotchTab) -> Void
    let onSelectTab: (NotchTab) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text(LanguageManager.tr("Notchify Features"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(pinnedTabs.count)/6 " + LanguageManager.tr("Pinned (Max 6)"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pinnedTabs.count >= 6 ? Color.orange : Color.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.vertical, 2)
            
            // Tab list
            VStack(spacing: 2) {
                ForEach(allTabs) { tab in
                    let isPinned = pinnedTabs.contains(tab)
                    let isSelected = viewModel.selectedTab == tab
                    let canPin = isPinned || pinnedTabs.count < 6
                    
                    TabPickerRowView(
                        tab: tab,
                        isSelected: isSelected,
                        isPinned: isPinned,
                        canPin: canPin,
                        onSelect: {
                            onSelectTab(tab)
                        },
                        onTogglePin: {
                            onTogglePin(tab)
                        }
                    )
                }
            }
        }
        .padding(10)
        .frame(width: 250)
    }
}
