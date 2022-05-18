import Flutter
import UIKit
import AVFoundation

public class SwiftQuickScanPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(ScanViewFactory(registrar.messenger()), withId: "scan_view")
    }
}

class ScanViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messager: FlutterBinaryMessenger

    init(_ messenger: FlutterBinaryMessenger) {
        self.messager = messenger
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let scanView = ScanView(frame: frame)
        let eventChannel = FlutterEventChannel(name: "quick_scan/scanview_\(viewId)/event", binaryMessenger: messager)
        eventChannel.setStreamHandler(scanView)
        return scanView
    }
}

class ScanView: UIView, FlutterPlatformView {
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var metadataOutput: AVCaptureMetadataOutput!

    private var sink: FlutterEventSink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear

        self.previewLayer = AVCaptureVideoPreviewLayer()
        self.previewLayer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(self.previewLayer)

        self.metadataOutput = AVCaptureMetadataOutput()
        self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        self.setupSession()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSession() {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
        captureSession.addInput(try! AVCaptureDeviceInput(device: device))
        captureSession.addOutput(self.metadataOutput)
        captureSession.startRunning()

        self.previewLayer.session = captureSession
        // https://stackoverflow.com/questions/26244714/avfoundation-metadata-object-types
        self.metadataOutput.metadataObjectTypes = [.qr]
    }
    
    func view() -> UIView {
        return self
    }
    
    override func layoutSubviews() {
        self.previewLayer.frame = self.bounds
        self.metadataOutput.rectOfInterest = self.previewLayer.metadataOutputRectConverted(fromLayerRect: self.previewLayer.bounds)
    }
}

extension ScanView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let result = metadataObjects.first as? AVMetadataMachineReadableCodeObject, result.type == .qr {
            self.sink?(result.stringValue)
        }
    }
}

extension ScanView: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.sink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.sink = nil
        return nil
    }
}
