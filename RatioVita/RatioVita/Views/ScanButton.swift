import SwiftUI

struct ScanButton: View {
    let isScanning: Bool
    let action: () -> Void
    
    init(isScanning: Bool, action: @escaping () -> Void) {
        self.isScanning = isScanning
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "camera.fill")
                        .font(DesignSystem.Typography.title3)
                }
                
                Text(isScanning ? "Scanning..." : "Scan")
                    .font(DesignSystem.Typography.bodyEmphasized)
            }
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [Color.ratioVitaPrimary, Color.ratioVitaSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadow(DesignSystem.Shadow.medium)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isScanning)
        .scaleEffect(isScanning ? 0.95 : 1.0)
        .animation(DesignSystem.Animation.spring, value: isScanning)
    }
}

// MARK: - Floating Scan Button

struct FloatingScanButton: View {
    let isScanning: Bool
    let action: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button {
                    action()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.ratioVitaPrimary, Color.ratioVitaSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(DesignSystem.Shadow.large)
                        
                        if isScanning {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isScanning)
                .scaleEffect(isScanning ? 0.9 : 1.0)
                .animation(DesignSystem.Animation.spring, value: isScanning)
                
                Spacer()
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
}
