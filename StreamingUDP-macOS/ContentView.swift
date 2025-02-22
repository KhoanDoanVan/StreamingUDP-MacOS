//
//  ContentView.swift
//  StreamingUDP-macOS
//
//  Created by Đoàn Văn Khoan on 22/2/25.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var streamer = ScreenStreamer()
    
    var body: some View {
        VStack {
            Text("Streaming Screen to iOS...")
                .font(.title)
                .padding()
            Button("Start Streaming") {
                Task {
                    await streamer.startStreaming()
                }
            }
            .padding()
        }
        .frame(width: 300, height: 200)
    }
}

#Preview {
    ContentView()
}
