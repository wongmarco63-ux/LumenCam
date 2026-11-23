import Foundation
import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import UIKit

// MARK: - Saved Gallery Item & Local Store
struct SavedPhotoItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let date: Date
}

@MainActor
final class LocalGalleryStore: ObservableObject {
    static let shared = LocalGalleryStore()
    @Published var items: [SavedPhotoItem] = []
    @Published var latestThumb: UIImage?

    private var folderURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("LumenGallery", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    init() { reload() }

    func reload() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) else {
            items = []
            latestThumb = nil
            return
        }
        let built: [SavedPhotoItem] = urls
            .filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }
            .map { u in
                let dt = (try? u.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return SavedPhotoItem(id: u.lastPathComponent, url: u, date: dt)
            }
            .sorted { $0.date > $1.date }
        items = built
        if let first = built.first, let data = try? Data(contentsOf: first.url), let img = UIImage(data: data) {
            latestThumb = Self.makeThumb(img)
        } else {
            latestThumb = nil
        }
    }

    func saveToGalleryAndPhotos(_ image: UIImage, saveToSystemPhotos: Bool = true) {
        let filename = "LUMEN_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        let dest = folderURL.appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.94) {
            try? data.write(to: dest, options: .atomic)
        }
        latestThumb = Self.makeThumb(image)
        reload()

        if saveToSystemPhotos {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else { return }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
        }
    }

    func delete(_ item: SavedPhotoItem) {
        try? FileManager.default.removeItem(at: item.url)
        reload()
    }

    func loadImage(for item: SavedPhotoItem) -> UIImage? {
        guard let data = try? Data(contentsOf: item.url) else { return nil }
        return UIImage(data: data)
    }

    private static func makeThumb(_ image: UIImage) -> UIImage {
        let side: CGFloat = 140
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let scale = max(side / max(1, image.size.width), side / max(1, image.size.height))
            let w = image.size.width * scale
            let h = image.size.height * scale
            image.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
    }
}

// MARK: - Thread-Safe AVFoundation Bridge
private final class CameraSessionBridge: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    let sessionQueue = DispatchQueue(label: "com.lumencam.session", qos: .userInitiated)
    let videoQueue = DispatchQueue(label: "com.lumencam.video", qos: .userInteractive)

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var baseZoomScale: CGFloat = 1.0
    private var isFront = false
    private var isConfigured = false

    private let stateLock = NSLock()
    private var sharedAdj = EditAdjustments()
    private var sharedAspect: AspectMode = .ratio34
    private var sharedHistogramOn = false
    private var pendingCaptureAdj = EditAdjustments()
    private var pendingCaptureAspect: AspectMode = .ratio34
    private var pendingCaptureEXIF = CameraEXIF()
    private var frameCounter = 0

    var onPreviewFrame: ((CGImage) -> Void)?
    var onHistogram: (([CGFloat]) -> Void)?
    var onEXIFUpdate: ((CameraEXIF) -> Void)?
    var onPhotoReady: ((UIImage?) -> Void)?
    var onZoomMeta: ((CGFloat, CGFloat) -> Void)?

    func syncState(adj: EditAdjustments, aspect: AspectMode, showHistogram: Bool) {
        stateLock.lock()
        sharedAdj = adj
        sharedAspect = aspect
        sharedHistogramOn = showHistogram
        stateLock.unlock()
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configureSession(front: self.isFront)
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.isFront.toggle()
            self.configureSession(front: self.isFront)
        }
    }

    func setUIZoom(_ uiZoom: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let dev = self.currentDevice else { return }
            let targetHW = max(dev.minAvailableVideoZoomFactor, min(dev.maxAvailableVideoZoomFactor, uiZoom * self.baseZoomScale))
            do {
                try dev.lockForConfiguration()
                dev.videoZoomFactor = targetHW
                dev.unlockForConfiguration()
            } catch {}
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self, let dev = self.currentDevice else { return }
            do {
                try dev.lockForConfiguration()
                if dev.isFocusPointOfInterestSupported {
                    dev.focusPointOfInterest = point
                    dev.focusMode = .autoFocus
                }
                if dev.isExposurePointOfInterestSupported {
                    dev.exposurePointOfInterest = point
                    dev.exposureMode = .autoExpose
                }
                dev.unlockForConfiguration()
            } catch {}
        }
    }

    func capture(flash: AVCaptureDevice.FlashMode, useHEIF: Bool, uiZoom: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            self.pendingCaptureAdj = self.sharedAdj
            self.pendingCaptureAspect = self.sharedAspect
            self.stateLock.unlock()
            self.pendingCaptureEXIF = self.readCurrentEXIF(uiZoom: uiZoom)

            let settings: AVCapturePhotoSettings
            if useHEIF && self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
            if self.photoOutput.supportedFlashModes.contains(flash) {
                settings.flashMode = flash
            }
            if let conn = self.photoOutput.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90
                if self.isFront && conn.isVideoMirroringSupported {
                    conn.isVideoMirrored = true
                }
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureSession(front: Bool) {
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let old = currentInput {
            session.removeInput(old)
            currentInput = nil
        }

        let device: AVCaptureDevice?
        if front {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        } else {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            )
            device = discovery.devices.first
        }

        guard let cam = device, let input = try? AVCaptureDeviceInput(device: cam) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
            currentDevice = cam
        }

        if !front && (cam.deviceType == .builtInTripleCamera || cam.deviceType == .builtInDualWideCamera) {
            let firstSwitch = cam.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue ?? 2.0
            baseZoomScale = CGFloat(firstSwitch)
        } else {
            baseZoomScale = 1.0
        }

        if !session.outputs.contains(videoOutput) {
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        }

        if !session.outputs.contains(photoOutput) {
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        }

        if let conn = videoOutput.connection(with: .video) {
            if conn.isVideoRotationAngleSupported(90) { conn.videoRotationAngle = 90 }
            if conn.isVideoMirroringSupported { conn.isVideoMirrored = front }
        }

        session.commitConfiguration()
        isConfigured = true

        // Default to 1x equivalent lens on back triple camera
        do {
            try cam.lockForConfiguration()
            let defaultHW = max(cam.minAvailableVideoZoomFactor, min(cam.maxAvailableVideoZoomFactor, baseZoomScale))
            cam.videoZoomFactor = defaultHW
            cam.unlockForConfiguration()
        } catch {}

        let minUI = cam.minAvailableVideoZoomFactor / max(1, baseZoomScale)
        let maxUI = min(10.0, cam.maxAvailableVideoZoomFactor / max(1, baseZoomScale))
        onZoomMeta?(minUI, maxUI)
    }

    private func readCurrentEXIF(uiZoom: CGFloat? = nil) -> CameraEXIF {
        guard let dev = currentDevice else { return CameraEXIF() }
        let isoVal = Int(round(dev.iso))
        let secs = CMTimeGetSeconds(dev.exposureDuration)
        let shutterText: String
        if secs > 0 && secs < 0.5 {
            shutterText = "1/\(max(1, Int(round(1.0 / secs))))s"
        } else if secs >= 0.5 {
            shutterText = String(format: "%.1fs", secs)
        } else {
            shutterText = "1/120s"
        }
        let z = uiZoom ?? (dev.videoZoomFactor / max(1, baseZoomScale))
        let mm = max(13, Int(round(24.0 * z)))
        let fNum = dev.lensAperture > 0 ? String(format: "f/%.1f", dev.lensAperture) : "f/1.8"
        return CameraEXIF(
            deviceName: UIDevice.current.modelNameFriendly,
            focalLength: "\(mm)mm",
            aperture: fNum,
            iso: "ISO \(isoVal)",
            shutter: shutterText
        )
    }

    // MARK: - Live Video Frame Processing
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        stateLock.lock()
        let adj = sharedAdj
        let aspect = sharedAspect
        let needHist = sharedHistogramOn
        stateLock.unlock()

        var ci = CIImage(cvPixelBuffer: pixelBuffer)
        ci = FilmPipeline.shared.cropToAspect(ci, ratio: aspect.aspectValue)

        // Downscale gently for smooth 30fps real-time preview with halation & grain
        let maxPreviewW: CGFloat = 720
        if ci.extent.width > maxPreviewW {
            let scale = maxPreviewW / ci.extent.width
            ci = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let processed = FilmPipeline.shared.process(ciImage: ci, adj: adj, isPreview: true)
        if let cg = FilmPipeline.shared.context.createCGImage(processed, from: processed.extent) {
            onPreviewFrame?(cg)
        }

        frameCounter += 1
        if needHist && frameCounter % 4 == 0 {
            let bins = computeHistogram(from: processed)
            onHistogram?(bins)
        }
        if frameCounter % 12 == 0 {
            let exif = readCurrentEXIF()
            onEXIFUpdate?(exif)
        }
    }

    private func computeHistogram(from image: CIImage) -> [CGFloat] {
        let count = 28
        let filter = CIFilter.areaHistogram()
        filter.inputImage = image
        filter.extent = image.extent
        filter.count = count
        filter.scale = 18.0
        guard let out = filter.outputImage else { return Array(repeating: 0.1, count: count) }

        var bitmap = [UInt8](repeating: 0, count: count * 4)
        FilmPipeline.shared.context.render(
            out,
            toBitmap: &bitmap,
            rowBytes: count * 4,
            bounds: CGRect(x: 0, y: 0, width: count, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        var rawVals: [CGFloat] = []
        rawVals.reserveCapacity(count)
        for i in 0..<count {
            let r = CGFloat(bitmap[i * 4])
            let g = CGFloat(bitmap[i * 4 + 1])
            let b = CGFloat(bitmap[i * 4 + 2])
            rawVals.append((r + g + b) / 3.0)
        }
        let peak = max(1.0, rawVals.max() ?? 1.0)
        return rawVals.map { max(0.06, $0 / peak) }
    }

    // MARK: - Still Photo Capture Delegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let rawImage = UIImage(data: data) else {
            onPhotoReady?(nil)
            return
        }
        let adj = pendingCaptureAdj
        let aspect = pendingCaptureAspect
        let exif = pendingCaptureEXIF
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let rendered = FilmPipeline.shared.renderUIImage(from: rawImage, adj: adj, aspect: aspect, exif: exif)
            self?.onPhotoReady?(rendered)
        }
    }
}

// MARK: - MainActor Observable Camera Controller
@MainActor
final class CameraManager: ObservableObject {
    @Published var previewCGImage: CGImage?
    @Published var histogramBins: [CGFloat] = Array(repeating: 0.15, count: 28)
    @Published var liveEXIF = CameraEXIF()
    @Published var uiZoom: CGFloat = 1.0
    @Published var minUIZoom: CGFloat = 0.5
    @Published var maxUIZoom: CGFloat = 8.0
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var useHEIF = true
    @Published var aspectMode: AspectMode = .ratio34 { didSet { pushState() } }
    @Published var showHistogram = false { didSet { pushState() } }
    @Published var adjustments = EditAdjustments() { didSet { pushState() } }
    @Published var isCapturing = false
    @Published var shutterFlash = false
    @Published var permissionDenied = false
    @Published var savedToast: String?

    private let bridge = CameraSessionBridge()

    init() {
        bridge.onPreviewFrame = { [weak self] cg in
            Task { @MainActor in self?.previewCGImage = cg }
        }
        bridge.onHistogram = { [weak self] bins in
            Task { @MainActor in self?.histogramBins = bins }
        }
        bridge.onEXIFUpdate = { [weak self] exif in
            Task { @MainActor in self?.liveEXIF = exif }
        }
        bridge.onZoomMeta = { [weak self] minZ, maxZ in
            Task { @MainActor in
                self?.minUIZoom = minZ
                self?.maxUIZoom = maxZ
                self?.uiZoom = 1.0
            }
        }
        bridge.onPhotoReady = { [weak self] rendered in
            Task { @MainActor in
                guard let self else { return }
                self.isCapturing = false
                if let img = rendered {
                    LocalGalleryStore.shared.saveToGalleryAndPhotos(img, saveToSystemPhotos: true)
                    self.showToast("已儲存膠片相片至相簿")
                } else {
                    self.showToast("拍攝處理失敗，請重試")
                }
            }
        }
    }

    func applyHomePreset(_ preset: HomePresetCard) {
        var next = adjustments
        next.filter = FilmCatalog.find(preset.filterID)
        next.intensity = 100
        next.border = preset.border
        next.grain = preset.grain
        next.halation = preset.halation
        next.softGlow = preset.softGlow
        adjustments = next
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionDenied = false
            pushState()
            bridge.startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                Task { @MainActor in
                    self?.permissionDenied = !ok
                    if ok {
                        self?.pushState()
                        self?.bridge.startSession()
                    }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        bridge.stopSession()
    }

    func setZoom(_ value: CGFloat) {
        let clamped = max(minUIZoom, min(maxUIZoom, value))
        uiZoom = clamped
        bridge.setUIZoom(clamped)
    }

    func flipCamera() {
        bridge.flipCamera()
    }

    func cycleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        default: flashMode = .auto
        }
    }

    func cycleAspect() {
        let all = AspectMode.allCases
        if let i = all.firstIndex(of: aspectMode) {
            aspectMode = all[(i + 1) % all.count]
        }
    }

    func focus(at normalizedPoint: CGPoint) {
        bridge.focus(at: normalizedPoint)
    }

    func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) { shutterFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            withAnimation(.easeOut(duration: 0.18)) { self?.shutterFlash = false }
        }
        bridge.capture(flash: flashMode, useHEIF: useHEIF, uiZoom: uiZoom)
    }

    private func pushState() {
        bridge.syncState(adj: adjustments, aspect: aspectMode, showHistogram: showHistogram)
    }

    private func showToast(_ msg: String) {
        withAnimation { savedToast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            withAnimation { self?.savedToast = nil }
        }
    }
}
