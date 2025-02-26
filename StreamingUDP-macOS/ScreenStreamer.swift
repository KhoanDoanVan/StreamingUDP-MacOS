//
//  ScreenStreamer.swift
//  StreamingUDP-macOS
//
//  Created by Đoàn Văn Khoan on 22/2/25.
//

import AVFoundation
import Network
import ScreenCaptureKit

class ScreenStreamer: NSObject, ObservableObject, SCStreamDelegate {
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "screenCaptureQueue")
    private var stream: SCStream?
    
    override init() {
        super.init()
        self.setupConnection()
    }
    
    func setupConnection() {
        let params = NWParameters.udp
        self.connection = NWConnection(host: "192.168.1.3", port: 5120, using: params) /// IP iPhone
        self.connection?.start(queue: self.queue)
    }

    func startStreaming() async {
        do {
            guard let display = try await SCShareableContent.current.displays.first else {
                print("❌ No Display Found")
                return
            }
            
            let config = SCStreamConfiguration()
            config.width = 640  // 🔥 Reduce resolution for stability
            config.height = 360
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: 15)
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            self.stream = SCStream(filter: filter, configuration: config, delegate: self)
            
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            try await stream?.startCapture()
            
        } catch {
            print("❌ Failed to start screen capture: \(error)")
        }
    }
}

extension ScreenStreamer: SCStreamOutput {
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let imageBuffer = sampleBuffer.imageBuffer else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            if let jpegData = nsImage.jpegData(compressionQuality: 0.7) {
                sendFrame(jpegData)
            }
        }
    }

    private func sendFrame(_ data: Data) {
        print("🔵 Sending frame: \(data.count) bytes")
        
        var size = UInt32(data.count).bigEndian
        let sizeData = Data(bytes: &size, count: MemoryLayout<UInt32>.size)
        let fullData = sizeData + data  // 🔥 Prepend size to data
        
        connection?.send(content: fullData, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Send error: \(error)")
            } else {
                print("✅ Frame sent successfully")
            }
        })
    }
}

extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
