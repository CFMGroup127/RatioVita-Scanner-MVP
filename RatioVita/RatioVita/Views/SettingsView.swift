import SwiftUI

struct SettingsView: View {
    @AppStorage("ocrEnabled") private var ocrEnabled = true
    @AppStorage("compressionEnabled") private var compressionEnabled = true
    @AppStorage("compressionQuality") private var compressionQuality = 0.8
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // Scanner Settings Section
                Section {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Enable OCR")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Extract text from receipts automatically")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $ocrEnabled)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Enable Compression")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Reduce file size for storage")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $compressionEnabled)
                                .labelsHidden()
                        }
                    
                    if compressionEnabled {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack {
                                    Text("Compression Quality")
                                        .font(DesignSystem.Typography.bodyEmphasized)
                                    
                                    Spacer()
                                    
                                    StatusBadge.info("\(Int(compressionQuality * 100))%")
                                }
                                
                            Slider(value: $compressionQuality, in: 0.1...1.0, step: 0.1)
                                    .accentColor(Color.ratioVitaPrimary)
                        }
                    }
                }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "Scanner Settings",
                        subtitle: "Configure receipt scanning behavior"
                    )
                }
                
                // Theme Settings Section
                Section {
                    NavigationLink {
                        ThemePreview()
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Appearance")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Customize colors and themes")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Circle()
                                    .fill(themeManager.customTheme.primaryColor)
                                    .frame(width: 12, height: 12)
                                
                                Circle()
                                    .fill(themeManager.customTheme.secondaryColor)
                                    .frame(width: 12, height: 12)
                                
                                Circle()
                                    .fill(themeManager.customTheme.accentColor)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                } header: {
                    SectionHeader(
                        title: "Appearance",
                        subtitle: "Customize the look and feel"
                    )
                }
                
                // About Section
                Section {
                    VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Version")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("1.0.0")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Build")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("RatioVita v2")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                        Spacer()
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "About",
                        subtitle: "App information and version"
                    )
                }
            }
            .navigationTitle("Settings")
            .ratioVitaTheme()
        }
    }
}
