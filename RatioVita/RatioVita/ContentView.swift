//
//  ContentView.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            ReceiptsView()
        } detail: {
            Text("Select a receipt")
        }
        .navigationTitle("Receipts")
        // .ratioVitaTheme() // Temporarily disabled for testing
        #else
        NavigationStack {
            ReceiptsView()
                .navigationTitle("Receipts")
        }
        // .ratioVitaTheme() // Temporarily disabled for testing
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
