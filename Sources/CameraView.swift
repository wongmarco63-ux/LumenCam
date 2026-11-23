import SwiftUI
import AVFoundation
import UIKit

enum ActiveEffectPanel: Equatable {
    case none, border, grain, halation, softGlow, tonePad
}

struct CameraView: View {
    @ObservedObject var cam: CameraManager
    @ObservedObject private var gallery = LocalGalleryStore.shared
    @Environment(\.dismiss) private var dismiss

    var onOpenGallery: () -> Void

    @State private var showFilterDrawer = false
    @State private var selectedCategory: FilmCategory = .kodak
    @State private var activeEffect: ActiveEffectPanel = .none
    @State private var showGrid = false
    @State private var showLiveEXIF = true
    @State private var filterEnabled = true
    @State private var favoriteIDs: Set<String> = ["portra", "800t", "film003"]
    @State private var focusPoint: CGPoint? = nil
    @State private var focusVisible = false

    private let zoomStops: [CGFloat] = [0.5, 1.0, 2.0, 4.0, 8.0]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                topToolbar

                viewfinderContainer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showFilterDrawer {
                    filterDrawerPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    if activeEffect != .none {
                        effectAdjustmentPanel
                            .transition(.opacity)
                    }
                    effectSelectorRow
                    shutterBottomBar
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 16)

            if let toast = cam.savedToast {
                VStack {
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 64)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden(false)
        .onAppear {
            selectedCategory = cam.adjustments.filter.category
            cam.start()
        }
        .onDisappear {
            cam.stop()
        }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            HStack(spacing: 18) {
                Button {
                    haptic()
                    withAnimation(.easeInOut(duration: 0.2)) { cam.showHistogram.toggle() }
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(cam.showHistogram ? Color.yellow : Color.white)
                }

                Button {
                    haptic()
                    cam.cycleAspect()
                } label: {
                    Text(cam.aspectMode.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 28)
                }

                Button {
                    haptic()
                    cam.useHEIF.toggle()
                } label: {
                    Text(cam.useHEIF ? "HEIF" : "JPG")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(cam.useHEIF ? Color.white : Color.yellow)
                        .frame(minWidth: 34)
                }

                Button {
                    haptic()
                    cam.flipCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }

                Button {
                    haptic()
                    showLiveEXIF.toggle()
                } label: {
                    Image(systemName: showLiveEXIF ? "viewfinder.circle" : "viewfinder.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(showLiveEXIF ? Color.white : Color.white.opacity(0.45))
                }

                Button {
                    haptic()
                    cam.cycleFlash()
                } label: {
                    Image(systemName: flashIconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(cam.flashMode == .on ? Color.yellow : Color.white)
                }

                Button {
                    haptic()
                    showGrid.toggle()
                } label: {
                    Image(systemName: showGrid ? "grid" : "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(showGrid ? Color.yellow : Color.white)
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private var flashIconName: String {
        switch cam.flashMode {
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        default: return "bolt.badge.a"
        }
    }

    // MARK: - Live Viewfinder
    private var viewfinderContainer: some View {
        GeometryReader { outer in
            ZStack {
                if cam.permissionDenied {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.white.opacity(0.45))
                        Text("請喺系統設定開啟相機權限")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                } else {
                    viewfinderFrame(maxSize: outer.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func viewfinderFrame(maxSize: CGSize) -> some View {
        let ratio = cam.aspectMode.aspectValue
        let fitW = min(maxSize.width, maxSize.height * ratio)
        let fitH = fitW / ratio

        return ZStack {
            liveBorderedPreview(width: fitW, height: fitH)
                .frame(width: fitW, height: fitH)
                .clipShape(RoundedRectangle(cornerRadius: cam.adjustments.border == .none ? 18 : 6, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { val in
                            let loc = val.location
                            let nx = max(0, min(1, loc.x / max(1, fitW)))
                            let ny = max(0, min(1, loc.y / max(1, fitH)))
                            cam.focus(at: CGPoint(x: nx, y: ny))
                            focusPoint = loc
                            withAnimation(.easeOut(duration: 0.14)) { focusVisible = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation(.easeOut(duration: 0.25)) { focusVisible = false }
                            }
                        }
                )
                .overlay {
                    if showGrid {
                        RuleOfThirdsGrid()
                            .stroke(Color.white.opacity(0.28), lineWidth: 0.7)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if focusVisible, let pt = focusPoint {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.yellow, lineWidth: 1.8)
                            .frame(width: 66, height: 66)
                            .position(pt)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if cam.showHistogram {
                        LiveHistogramOverlay(bins: cam.histogramBins)
                            .padding(12)
                    }
                }
                .overlay(alignment: .bottom) {
                    if !showFilterDrawer {
                        VStack(spacing: 10) {
                            if cam.adjustments.border == .none && showLiveEXIF {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("SHOT ON")
                                            .font(.system(size: 7.5, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                        Text(cam.liveEXIF.deviceName)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.92))
                                    }
                                    Rectangle()
                                        .fill(Color.white.opacity(0.45))
                                        .frame(width: 1, height: 20)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(cam.liveEXIF.focalLength)  \(cam.liveEXIF.aperture)")
                                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.9))
                                        Text("\(cam.liveEXIF.iso)  \(cam.liveEXIF.shutter)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.72))
                                    }
                                }
                                .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                            }

                            HStack(alignment: .bottom) {
                                tonePadButton
                                Spacer(minLength: 8)
                                zoomPillBar
                                Spacer(minLength: 8)
                                Color.clear.frame(width: 44, height: 1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                    } else {
                        HStack {
                            tonePadButton
                            Spacer()
                        }
                        .padding(12)
                    }
                }
                .overlay {
                    if cam.shutterFlash {
                        Color.white.opacity(0.75)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
        }
    }

    @ViewBuilder
    private func liveBorderedPreview(width: CGFloat, height: CGFloat) -> some View {
        let style = cam.adjustments.border
        if style == .none {
            rawPreviewImage
        } else {
            ZStack {
                if style == .liquidGlass {
                    rawPreviewImage
                        .blur(radius: 26)
                        .scaleEffect(1.22)
                        .overlay(Color.white.opacity(0.12))
                } else if style == .polaroid {
                    Color(white: 0.97)
                } else {
                    Color(white: 0.08)
                }

                VStack(spacing: 0) {
                    rawPreviewImage
                        .frame(width: width * 0.87, height: height * 0.77)
                        .clipShape(RoundedRectangle(cornerRadius: style == .liquidGlass ? 14 : 2, style: .continuous))
                        .shadow(color: style == .liquidGlass ? Color.black.opacity(0.35) : Color.clear, radius: 12, y: 6)
                        .padding(.top, width * 0.065)

                    Spacer(minLength: 4)

                    VStack(spacing: 2) {
                        Text("Shot on \(cam.liveEXIF.deviceName)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(style == .polaroid ? Color(white: 0.12) : Color.white.opacity(0.92))
                        Text("\(cam.liveEXIF.aperture)  \(cam.liveEXIF.iso)  \(cam.liveEXIF.shutter)  \(cam.liveEXIF.focalLength)")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(style == .polaroid ? Color(white: 0.45) : Color.white.opacity(0.68))
                    }
                    .padding(.bottom, height * 0.045)
                }
            }
        }
    }

    @ViewBuilder
    private var rawPreviewImage: some View {
        if let cg = cam.previewCGImage {
            Image(decorative: cg, scale: 1.0)
                .resizable()
                .scaledToFill()
        } else {
            Color(white: 0.1)
                .overlay(ProgressView().tint(.white.opacity(0.6)))
        }
    }

    // MARK: - 2D Tone Pad Button & Zoom Pill
    private var tonePadButton: some View {
        Button {
            haptic()
            withAnimation(.easeInOut(duration: 0.2)) {
                activeEffect = (activeEffect == .tonePad) ? .none : .tonePad
            }
        } label: {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "6FA3C7"), Color(hex: "D9A077"), Color(hex: "3B4652")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .offset(x: CGFloat(cam.adjustments.toneX) * 14, y: CGFloat(-cam.adjustments.toneY) * 14)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(activeEffect == .tonePad ? Color.yellow : Color.white.opacity(0.35), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private var zoomPillBar: some View {
        HStack(spacing: 2) {
            ForEach(zoomStops, id: \.self) { z in
                let isSelected = abs(cam.uiZoom - z) < 0.28
                Button {
                    haptic()
                    cam.setZoom(z)
                } label: {
                    Text(z == 0.5 ? "0.5×" : "\(Int(z))×")
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.75))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.white.opacity(0.22) : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial.opacity(0.85), in: Capsule())
    }

    // MARK: - Effect Bar & Inline Adjustment Panel
    private var effectSelectorRow: some View {
        HStack(spacing: 22) {
            effectTabButton(title: "邊框", panel: .border, isActive: cam.adjustments.border != .none, showBadgeIcon: true)
            effectTabButton(title: "顆粒", panel: .grain, isActive: cam.adjustments.grain > 0.02, showBadgeIcon: false)
            effectTabButton(title: "膠片輝光", panel: .halation, isActive: cam.adjustments.halation > 0.02, showBadgeIcon: false)
            effectTabButton(title: "柔光", panel: .softGlow, isActive: cam.adjustments.softGlow > 0.02, showBadgeIcon: false)
        }
        .padding(.top, 2)
    }

    private func effectTabButton(title: String, panel: ActiveEffectPanel, isActive: Bool, showBadgeIcon: Bool) -> some View {
        let selected = activeEffect == panel
        return Button {
            haptic()
            withAnimation(.easeInOut(duration: 0.18)) {
                activeEffect = selected ? .none : panel
            }
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13.5, weight: selected || isActive ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.yellow : (isActive ? Color.white : Color.white.opacity(0.55)))
                if showBadgeIcon {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 11))
                        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.45))
                        .padding(3)
                        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var effectAdjustmentPanel: some View {
        VStack(spacing: 8) {
            switch activeEffect {
            case .border:
                HStack(spacing: 8) {
                    ForEach(BorderStyle.allCases) { b in
                        let on = cam.adjustments.border == b
                        Button {
                            haptic()
                            cam.adjustments.border = b
                        } label: {
                            Text(b.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(on ? Color.black : Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(on ? Color.white : Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            case .grain:
                effectSlider(label: "膠片顆粒", value: $cam.adjustments.grain)
            case .halation:
                effectSlider(label: "800T 紅橙輝光", value: $cam.adjustments.halation)
            case .softGlow:
                effectSlider(label: "黑柔光暈", value: $cam.adjustments.softGlow)
            case .tonePad:
                TonePad2DControl(toneX: $cam.adjustments.toneX, toneY: $cam.adjustments.toneY)
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func effectSlider(label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 84, alignment: .leading)
            Slider(value: value, in: 0...1)
                .tint(.white)
            Text("\(Int(value.wrappedValue * 100))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Bottom Shutter Bar
    private var shutterBottomBar: some View {
        HStack {
            // Left: Gallery
            Button {
                haptic()
                onOpenGallery()
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 44, height: 44)
                        if let thumb = gallery.latestThumb {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    Text("畫廊")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .frame(width: 72)

            Spacer()

            // Center: Pro Shutter Button
            Button {
                cam.capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3.5)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(Color(white: cam.isCapturing ? 0.55 : 0.86))
                        .frame(width: 62, height: 62)
                        .scaleEffect(cam.isCapturing ? 0.90 : 1.0)
                        .animation(.easeOut(duration: 0.12), value: cam.isCapturing)
                }
            }
            .buttonStyle(.plain)
            .disabled(cam.isCapturing)

            Spacer()

            // Right: Film Filter Drawer Trigger
            Button {
                haptic()
                activeEffect = .none
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showFilterDrawer = true
                }
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(hex: cam.adjustments.filter.previewColors.first ?? "555555"),
                                Color(hex: cam.adjustments.filter.previewColors.last ?? "222222")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "camera.filters")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )

                    Text(cam.adjustments.filter.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 72)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }

    // MARK: - Slide-Up Film Filter Drawer (Matches Screenshot 8)
    private var filterDrawerPanel: some View {
        let recipes = FilmCatalog.recipes(in: selectedCategory)
        let current = cam.adjustments.filter
        let isFav = favoriteIDs.contains(current.id)

        return VStack(spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    Text(current.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Button {
                        haptic()
                        if isFav { favoriteIDs.remove(current.id) } else { favoriteIDs.insert(current.id) }
                    } label: {
                        Image(systemName: isFav ? "star.fill" : "star")
                            .font(.system(size: 15))
                            .foregroundStyle(isFav ? Color.yellow : Color.white.opacity(0.8))
                    }
                }

                Spacer()

                Toggle("", isOn: $filterEnabled)
                    .labelsHidden()
                    .tint(Color.white.opacity(0.35))
                    .onChange(of: filterEnabled) { _, on in
                        cam.adjustments.intensity = on ? 100 : 0
                    }

                Button {
                    haptic()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        showFilterDrawer = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal, 6)

            // 4 Film Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(FilmCategory.allCases) { cat in
                        let sel = selectedCategory == cat
                        Button {
                            haptic()
                            selectedCategory = cat
                        } label: {
                            VStack(spacing: 6) {
                                Text(cat.rawValue)
                                    .font(.system(size: 12.5, weight: sel ? .bold : .regular))
                                    .foregroundStyle(sel ? Color.white : Color.white.opacity(0.55))
                                Rectangle()
                                    .fill(sel ? Color.white : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Film Swatch Thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recipes) { r in
                        let picked = r.id == current.id
                        Button {
                            haptic()
                            cam.adjustments.filter = r
                            if !filterEnabled {
                                filterEnabled = true
                                cam.adjustments.intensity = 100
                            }
                            if r.id == "800t" && cam.adjustments.halation < 0.1 {
                                cam.adjustments.halation = 0.55
                            }
                        } label: {
                            ZStack(alignment: .bottom) {
                                LinearGradient(
                                    colors: [
                                        Color(hex: r.previewColors.first ?? "444444"),
                                        Color(hex: r.previewColors.last ?? "111111")
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                Image(systemName: "mountain.2.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .padding(.bottom, 18)
                                Text(r.name)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 3)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.45))
                            }
                            .frame(width: 58, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(picked ? Color.white : Color.clear, lineWidth: 2.2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Intensity 0 - 100 Slider
            HStack(spacing: 12) {
                Slider(value: $cam.adjustments.intensity, in: 0...100, step: 1)
                    .tint(.white)
                Text("\(Int(cam.adjustments.intensity))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Helper Subviews
struct LiveHistogramOverlay: View {
    let bins: [CGFloat]
    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(Array(bins.enumerated()), id: \.offset) { _, val in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.78))
                    .frame(width: 2.5, height: max(2, val * 26))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RuleOfThirdsGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 1...2 {
            let x = rect.width * CGFloat(i) / 3.0
            let y = rect.height * CGFloat(i) / 3.0
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return p
    }
}

struct TonePad2DControl: View {
    @Binding var toneX: Double
    @Binding var toneY: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("色調偏移（冷暖 × 反差）")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button("重置") {
                    toneX = 0
                    toneY = 0
                }
                .font(.caption.bold())
                .foregroundStyle(.yellow)
            }

            GeometryReader { g in
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "3D7EA6"), Color(hex: "8A8A8A"), Color(hex: "D98A4E")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.clear, Color.black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                        .frame(width: 18, height: 18)
                        .position(
                            x: g.size.width * CGFloat((toneX + 1) / 2),
                            y: g.size.height * CGFloat((1 - toneY) / 2)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let nx = (val.location.x / max(1, g.size.width)) * 2 - 1
                            let ny = 1 - (val.location.y / max(1, g.size.height)) * 2
                            toneX = max(-1, min(1, Double(nx)))
                            toneY = max(-1, min(1, Double(ny)))
                        }
                )
            }
            .frame(height: 86)
        }
    }
}
