import SwiftUI
import UIKit

struct ScanSheet: View {
    @ObservedObject var vm: MahjongViewModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager: CameraManager = CameraManager()

    private let recognizer = TileRecognizer(modelName: "TileModel")

    @State private var message: String = ""
    @State private var isBusy: Bool = false

    @State private var autoDetectedRowRect: CGRect? = nil
    @State private var recognizedTiles: [TileRecognizer.TileOverlay] = []
    @State private var pendingRecognizedIDs: [Int] = []
    @State private var isReviewingRecognition: Bool = false
    @State private var isLiveRecognizing: Bool = false
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    var body: some View {
        ZStack {
            CameraPreview(manager: manager)
                .ignoresSafeArea()

            GuideOverlay(normalizedRect: autoDetectedRowRect,
                         tileOverlays: recognizedTiles,
                         language: vm.language,
                         deviceOrientation: deviceOrientation)

            VStack(spacing: 10) {
                HStack {
                    Button(AppText.cancel(vm.language)) {
                        dismiss()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .appleClip(AppleCornerRadius.panel)

                    Spacer()

                    Button(isBusy ? AppText.processing(vm.language) : AppText.scan(vm.language)) {
                        startScan()
                    }
                    .disabled(isBusy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .appleClip(AppleCornerRadius.panel)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                if isReviewingRecognition, !recognizedTiles.isEmpty {
                    RecognitionResultPanel(tiles: recognizedTiles,
                                           language: vm.language,
                                           onUse: acceptRecognitionResult,
                                           onRescan: startScan)
                        .padding(.horizontal, 16)
                }

                Text(message)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .appleClip(AppleCornerRadius.panel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .onAppear {
            message = AppText.scanInstruction(vm.language)
            lockScanInterfaceOrientation()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updateDeviceOrientation(UIDevice.current.orientation)

            manager.requestCameraPermissionIfNeeded { ok in
                if ok {
                    manager.startSession()
                } else {
                    manager.stopSession()
                    message = AppText.cameraPermissionDenied(vm.language)
                }
            }
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            unlockInterfaceOrientation()
            manager.stopSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateDeviceOrientation(UIDevice.current.orientation)
        }
        .onReceive(manager.$state, perform: handleStateChange)
        .onReceive(manager.$liveSnapshot) { snapshot in
            handleLiveSnapshot(snapshot)
        }
        .onChange(of: vm.language) { _, _ in
            if isReviewingRecognition {
                message = AppText.recognitionReady(count: pendingRecognizedIDs.count,
                                                   language: vm.language)
            } else if !isBusy {
                message = AppText.scanInstruction(vm.language)
            }
        }
    }

    private func handleLiveSnapshot(_ snapshot: FrameSnapshot?) {
        guard let snapshot else { return }
        guard !isBusy, !isReviewingRecognition, !isLiveRecognizing else { return }

        isLiveRecognizing = true

        Task {
            do {
                let result = try await recognizer.recognizeLiveOverlay(snapshot: snapshot)

                await MainActor.run {
                    if self.isBusy || self.isReviewingRecognition {
                        self.isLiveRecognizing = false
                        return
                    }

                    self.autoDetectedRowRect = result.normalizedRowRect
                    self.recognizedTiles = result.tiles
                    self.isLiveRecognizing = false
                }
            } catch {
                await MainActor.run {
                    if !self.isBusy && !self.isReviewingRecognition {
                        self.autoDetectedRowRect = nil
                        self.recognizedTiles = []
                    }
                    self.isLiveRecognizing = false
                }
            }
        }
    }

    private func lockScanInterfaceOrientation() {
        AppOrientationState.updateSupportedOrientations(.portrait)
    }

    private func unlockInterfaceOrientation() {
        AppOrientationState.updateSupportedOrientations(.allButUpsideDown)
    }

    private func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
        if orientation == .portrait ||
            orientation == .portraitUpsideDown ||
            orientation == .landscapeLeft ||
            orientation == .landscapeRight {
            deviceOrientation = orientation
            manager.updateDeviceOrientation(orientation)
        }
    }

    private func startScan() {
        guard case .running = manager.state else {
            message = AppText.cameraNotReady(vm.language)
            return
        }

        isBusy = true
        autoDetectedRowRect = nil
        recognizedTiles = []
        pendingRecognizedIDs = []
        isReviewingRecognition = false
        message = AppText.scanning(vm.language)

        manager.captureBurst(targetCount: 10, interval: 0.12)
    }

    private func handleStateChange(_ state: ScanState) {
        switch state {
        case .captured(let count):
            message = AppText.capturedFrames(count, language: vm.language)

            Task {
                do {
                    let result = try await recognizer.recognizeWithOverlay(snapshots: manager.snapshots)

                    await MainActor.run {
                        self.autoDetectedRowRect = result.normalizedRowRect
                        self.recognizedTiles = result.tiles
                        self.pendingRecognizedIDs = result.ids

                        if result.ids.isEmpty {
                            self.message = AppText.recognizerReturnedEmpty(vm.language)
                            self.isBusy = false
                            self.isReviewingRecognition = false
                            manager.readyForNextCapture()
                            return
                        }

                        self.message = AppText.recognitionReady(count: result.ids.count,
                                                                language: vm.language)
                        self.isBusy = false
                        self.isReviewingRecognition = true
                        manager.readyForNextCapture()
                    }
                } catch {
                    await MainActor.run {
                        self.autoDetectedRowRect = nil
                        self.recognizedTiles = []
                        self.pendingRecognizedIDs = []
                        self.isReviewingRecognition = false
                        self.message = AppText.recognitionFailed(localizedRecognizerError(error),
                                                                 language: vm.language)
                        self.isBusy = false
                        manager.readyForNextCapture()
                    }
                }
            }

        case .failed(let msg):
            message = AppText.scanError(CameraFailureMessage.localized(msg, language: vm.language),
                                        language: vm.language)
            isBusy = false
            autoDetectedRowRect = nil
            recognizedTiles = []
            pendingRecognizedIDs = []
            isReviewingRecognition = false

        default:
            break
        }
    }

    private func acceptRecognitionResult() {
        guard !pendingRecognizedIDs.isEmpty else { return }

        vm.replaceHandFromScan(tiles: pendingRecognizedIDs)
        if !vm.statusText.isEmpty {
            message = vm.statusText
            isReviewingRecognition = false
            manager.readyForNextCapture()
            return
        }

        dismiss()
    }

    private func localizedRecognizerError(_ error: Error) -> String {
        if let recognizerError = error as? YOLOTileRecognizerError {
            return recognizerError.message(language: vm.language)
        }
        return error.localizedDescription
    }
}

private struct GuideOverlay: View {
    let normalizedRect: CGRect?
    let tileOverlays: [TileRecognizer.TileOverlay]
    let language: AppLanguage
    let deviceOrientation: UIDeviceOrientation

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let screenHeight = geo.size.height

            ZStack {
                if let rect = normalizedRect,
                   rect.width > 0,
                   rect.height > 0 {

                    let x = rect.minX * screenWidth
                    let y = (1.0 - rect.maxY) * screenHeight
                    let w = rect.width * screenWidth
                    let h = rect.height * screenHeight

                    AppleCornerShape.continuous(AppleCornerRadius.overlayGuide)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: w, height: h)
                        .position(x: x + w / 2.0, y: y + h / 2.0)
                        .shadow(radius: 6)
                } else {
                    let scanFrame = defaultScanFrame(screenWidth: screenWidth,
                                                     screenHeight: screenHeight)

                    AppleCornerShape.continuous(AppleCornerRadius.overlayGuide)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                        .frame(width: scanFrame.width, height: scanFrame.height)
                        .position(x: screenWidth * 0.5, y: scanFrame.centerY)
                        .foregroundColor(.white.opacity(0.75))
                        .shadow(radius: 6)
                }

                ForEach(tileOverlays) { tile in
                    tileBox(tile,
                            screenWidth: screenWidth,
                            screenHeight: screenHeight)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func tileBox(_ tile: TileRecognizer.TileOverlay,
                         screenWidth: CGFloat,
                         screenHeight: CGFloat) -> some View {
        let rect = tile.normalizedRect
        let x = rect.minX * screenWidth
        let y = (1.0 - rect.maxY) * screenHeight
        let w = max(rect.width * screenWidth, 26)
        let h = max(rect.height * screenHeight, 34)
        let label = MahjongEngine.tileName34(tile.tileIndex, language: language)
        let color = Color.green

        return ZStack(alignment: .topLeading) {
            AppleCornerShape.continuous(8)
                .stroke(color, lineWidth: 2)

            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 5)
                .frame(height: 18)
                .background(color.opacity(0.92))
                .appleClip(6)
                .offset(y: -20)
        }
        .frame(width: w, height: h)
        .position(x: x + w / 2.0, y: y + h / 2.0)
        .shadow(radius: 4)
    }

    private func defaultScanFrame(screenWidth: CGFloat,
                                  screenHeight: CGFloat) -> (width: CGFloat, height: CGFloat, centerY: CGFloat) {
        let isLandscapeDevice = deviceOrientation == .landscapeLeft ||
            deviceOrientation == .landscapeRight
        let phoneShortSide = min(screenWidth, screenHeight)
        let phoneLongSide = max(screenWidth, screenHeight)
        let phoneAspect = phoneLongSide / phoneShortSide

        if isLandscapeDevice {
            let height = screenHeight * 0.76
            return (width: height / phoneAspect,
                    height: height,
                    centerY: screenHeight * 0.55)
        }

        let width = screenWidth * 0.98
        return (width: width,
                height: width / phoneAspect * 1.35,
                centerY: screenHeight * 0.66)
    }
}

private struct RecognitionResultPanel: View {
    let tiles: [TileRecognizer.TileOverlay]
    let language: AppLanguage
    let onUse: () -> Void
    let onRescan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppText.recognizedTilesTitle(count: tiles.count, language: language))
                    .font(.footnote.weight(.semibold))
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tiles) { tile in
                        VStack(spacing: 2) {
                            Text(MahjongEngine.tileName34(tile.tileIndex, language: language))
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(Int(tile.confidence * 100))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 52, height: 44)
                        .background(Color(.systemBackground).opacity(0.92))
                        .appleClip(AppleCornerRadius.badge)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: onRescan) {
                    Text(AppText.rescan(language))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(.systemBackground).opacity(0.9))
                        .appleClip(AppleCornerRadius.control)
                }
                .buttonStyle(.plain)

                Button(action: onUse) {
                    Text(AppText.useRecognitionResult(language))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.accentColor)
                        .appleClip(AppleCornerRadius.control)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .appleClip(AppleCornerRadius.panel)
    }
}
