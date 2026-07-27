import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScan = { scannedUrl in
            onScan(scannedUrl)
            presentationMode.wrappedValue.dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var captureSession: AVCaptureSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermission()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showError(message: "Kamera izni verilmedi. Ayarlardan izin verebilirsiniz.")
                    }
                }
            }
        default:
            showError(message: "Kamera erişimi engellenmiş.")
        }
    }

    private func setupCamera() {
        // 1. Fiziksel Kamera Kontrolü (Simülatör Koruma)
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showError(message: "Simülatörde veya bu cihazda kamera bulunamadı.")
            return
        }

        let session = AVCaptureSession()

        // 2. Kamera Girdisi Oluşturma
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            showError(message: "Kamera girdisi başlatılamadı.")
            return
        }
        session.addInput(videoInput)

        // 3. QR Kod Çıktı Analizcisi
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr] // Sadece QR kodlarını tara
        } else {
            showError(message: "QR analizi başlatılamadı.")
            return
        }

        // 4. Canlı Kamera Ekranı Katmanı
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.captureSession = session

        // 5. Arka planda kamerayı çalıştır (UI bloklanmasın)
        DispatchQueue.global(qos: .background).async {
            session.startRunning()
        }
    }

    private func showError(message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.padding = 20
        label.frame = view.bounds
        view.addSubview(label)
    }

    // QR Kod Okunduğunda Çalışan Tetikleyici
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            
            // Titreşim ver
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            // Taramayı durdur ve sonucu ilet
            captureSession?.stopRunning()
            onScan?(stringValue)
        }
    }
}

// UILabel İçin Yardımcı Padding Extension'ı
private extension UILabel {
    var padding: CGFloat {
        get { return 0 }
        set {
            let mode = frame
            frame = mode.insetBy(dx: newValue, dy: newValue)
        }
    }
}
