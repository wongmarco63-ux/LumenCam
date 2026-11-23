import SwiftUI
import PhotosUI
import UIKit

@main
struct LumenCamApp: App {
    var body: some Scene {
        WindowGroup {
            MainShellView()
                .preferredColorScheme(.dark)
        }
    }
}

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct LumenShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Root Shell with Floating 4-Tab Capsule
struct MainShellView: View {
    @StateObject private var cam = CameraManager()
    @State private var selectedTab = 0
    @State private var showCamera = false
    @State private var importPickerItem: PhotosPickerItem?
    @State private var editingImage: IdentifiableImage?
    @State private var initialEditorAdj = EditAdjustments()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(white: 0.05).ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0:
                    RecipeHomeView(
                        cam: cam,
                        importPickerItem: $importPickerItem,
                        onLaunchCamera: { preset in
                            cam.applyHomePreset(preset)
                            showCamera = true
                        }
                    )
                case 1:
                    AIColorLabView { img, adj in
                        initialEditorAdj = adj
                        editingImage = IdentifiableImage(image: img)
                    }
                case 2:
                    FilterLibraryView(
                        onPickForCamera: { recipe in
                            cam.adjustments.filter = recipe
                            cam.adjustments.intensity = 100
                            showCamera = true
                        }
                    )
                default:
                    GalleryTabView { img in
                        initialEditorAdj = EditAdjustments()
                        editingImage = IdentifiableImage(image: img)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 82)

            floatingTabBar
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(cam: cam) {
                showCamera = false
                selectedTab = 3
            }
        }
        .sheet(item: $editingImage) { item in
            PhotoEditorView(sourceImage: item.image, initialAdj: initialEditorAdj)
        }
        .onChange(of: importPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        initialEditorAdj = cam.adjustments
                        editingImage = IdentifiableImage(image: img)
                        importPickerItem = nil
                    }
                }
            }
        }
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabPill(index: 0) {
                Image(systemName: "house.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
            tabPill(index: 1) {
                Text("AI")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            tabPill(index: 2) {
                Image(systemName: "camera.filters")
                    .font(.system(size: 18, weight: .semibold))
            }
            tabPill(index: 3) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .padding(6)
        .background(Color(white: 0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
    }

    private func tabPill<Content: View>(index: Int, @ViewBuilder label: () -> Content) -> some View {
        let active = selectedTab == index
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                selectedTab = index
            }
        } label: {
            label()
                .foregroundStyle(active ? Color.white : Color.white.opacity(0.48))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(active ? Color.white.opacity(0.14) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TAB 0: Home Recipe Carousel ("配方")
struct RecipeHomeView: View {
    @ObservedObject var cam: CameraManager
    @Binding var importPickerItem: PhotosPickerItem?
    var onLaunchCamera: (HomePresetCard) -> Void

    @State private var activePresetID: String? = FilmCatalog.homePresets.first?.id
    @State private var showInfoAlert = false

    private var currentPreset: HomePresetCard {
        FilmCatalog.homePresets.first { $0.id == activePresetID } ?? FilmCatalog.homePresets[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button {
                    showInfoAlert = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }

                Text("配方")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.leading, 4)

                Spacer()

                PhotosPicker(selection: $importPickerItem, matching: .images) {
                    Text("導入")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Color(white: 0.17), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer(minLength: 16)

            // Center Peek-Card Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(FilmCatalog.homePresets) { preset in
                        PresetShowcaseCard(preset: preset, isActive: preset.id == currentPreset.id)
                            .containerRelativeFrame(.horizontal) { len, _ in min(len - 120, 250) }
                            .id(preset.id)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onLaunchCamera(preset)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 60, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $activePresetID)
            .frame(height: 335)

            // Large Pill Shoot Button ("拍攝")
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onLaunchCamera(currentPreset)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("拍攝")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color(white: 0.16), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 26)

            Spacer(minLength: 18)
        }
        .alert("LumenCam 膠片相機", isPresented: $showInfoAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text("全部 16 款膠片配方、液態玻璃邊框、800T 輝光與離線 AI 仿色均已完全解鎖，點「拍攝」或「導入」即可使用。")
        }
    }
}

struct PresetShowcaseCard: View {
    let preset: HomePresetCard
    let isActive: Bool

    var body: some View {
        let colors = preset.gradientHex.map { Color(hex: $0) }
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            if preset.border == .polaroid {
                VStack(spacing: 0) {
                    LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                        .padding(10)
                        .background(Color(white: 0.96))
                    Rectangle()
                        .fill(Color(white: 0.96))
                        .frame(height: 52)
                }
                .padding(.top, 24)
            } else if preset.border == .liquidGlass {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .padding(12)
            }

            // Atmospheric visual motif
            Image(systemName: preset.id == "cine800t" ? "sparkles" : (preset.id == "glass" ? "drop.fill" : (preset.id == "ricoh" ? "tree.fill" : "sun.horizon.fill")))
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.28))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 44)

            // Bottom dark vignette for crisp title
            LinearGradient(colors: [.clear, Color.black.opacity(0.78)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 5) {
                Text(preset.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(preset.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(isActive ? 0.28 : 0.08), lineWidth: 1)
        )
        .scaleEffect(isActive ? 1.0 : 0.94)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isActive)
    }
}

// MARK: - TAB 1: Offline AI Smart Color Transfer ("AI 智能仿色")
struct AIColorLabView: View {
    var onOpenInEditor: (UIImage, EditAdjustments) -> Void

    @State private var targetPicker: PhotosPickerItem?
    @State private var refPicker: PhotosPickerItem?
    @State private var targetImage: UIImage?
    @State private var refImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var strength: Double = 0.80
    @State private var computedTransfer: ColorTransferParams?
    @State private var isProcessing = false
    @State private var savedToast: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 智能仿色")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Text("揀一張參考大師相片，離線自動分析色調並套落你嘅相片")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                // Result Preview Box
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(white: 0.11))
                    if let img = previewImage ?? targetImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(8)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.35))
                            Text("先揀選下方「目標相片」同「參考色調圖」")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    if isProcessing {
                        ProgressView().tint(.white)
                            .padding(14)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .frame(height: 280)

                // Pickers Row
                HStack(spacing: 12) {
                    PhotosPicker(selection: $targetPicker, matching: .images) {
                        pickerCard(title: "1. 目標相片", thumb: targetImage, icon: "photo")
                    }
                    PhotosPicker(selection: $refPicker, matching: .images) {
                        pickerCard(title: "2. 參考大師圖", thumb: refImage, icon: "paintpalette.fill")
                    }
                }

                // Strength Slider
                if computedTransfer != nil {
                    VStack(spacing: 8) {
                        HStack {
                            Text("仿色強度")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(Int(strength * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.yellow)
                        }
                        Slider(value: $strength, in: 0...1)
                            .tint(.white)
                            .onChange(of: strength) { _, _ in renderMatch() }
                    }
                    .padding(16)
                    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    HStack(spacing: 12) {
                        Button {
                            if let src = targetImage, let transfer = computedTransfer {
                                var adj = EditAdjustments()
                                adj.intensity = 0
                                adj.grain = 0
                                adj.aiTransfer = transfer
                                adj.aiStrength = strength
                                onOpenInEditor(src, adj)
                            }
                        } label: {
                            Text("加邊框 / 精修")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(white: 0.18), in: Capsule())
                        }

                        Button {
                            if let out = previewImage {
                                LocalGalleryStore.shared.saveToGalleryAndPhotos(out, saveToSystemPhotos: true)
                                savedToast = "已儲存 AI 仿色相片至相簿"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedToast = nil }
                            }
                        } label: {
                            Text("儲存原圖")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white, in: Capsule())
                        }
                    }
                }

                if let msg = savedToast {
                    Text(msg)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .onChange(of: targetPicker) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    await MainActor.run { targetImage = img.normalizedUp(); recomputeIfReady() }
                }
            }
        }
        .onChange(of: refPicker) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    await MainActor.run { refImage = img.normalizedUp(); recomputeIfReady() }
                }
            }
        }
    }

    private func pickerCard(title: String, thumb: UIImage?, icon: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.14))
                    .frame(height: 86)
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private func recomputeIfReady() {
        guard let src = targetImage, let ref = refImage else { return }
        computedTransfer = AIColorMatcher.analyze(source: src, reference: ref)
        renderMatch()
    }

    private func renderMatch() {
        guard let src = targetImage, let transfer = computedTransfer else { return }
        isProcessing = true
        let s = strength
        DispatchQueue.global(qos: .userInitiated).async {
            var adj = EditAdjustments()
            adj.intensity = 0
            adj.grain = 0
            adj.aiTransfer = transfer
            adj.aiStrength = s
            let out = FilmPipeline.shared.renderUIImage(from: src, adj: adj, aspect: nil, exif: CameraEXIF())
            DispatchQueue.main.async {
                previewImage = out
                isProcessing = false
            }
        }
    }
}

// MARK: - TAB 2: All 16 Film Recipes Library
struct FilterLibraryView: View {
    var onPickForCamera: (FilmRecipe) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("膠片濾鏡庫")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                ForEach(FilmCategory.allCases) { cat in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(cat.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(FilmCatalog.recipes(in: cat)) { recipe in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onPickForCamera(recipe)
                                } label: {
                                    ZStack(alignment: .bottomLeading) {
                                        LinearGradient(
                                            colors: [
                                                Color(hex: recipe.previewColors.first ?? "444444"),
                                                Color(hex: recipe.previewColors.last ?? "111111")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(recipe.name)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.white)
                                                Text("點擊用此膠片拍攝")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.white.opacity(0.65))
                                            }
                                            Spacer()
                                            Image(systemName: "camera.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        .padding(12)
                                    }
                                    .frame(height: 86)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - TAB 3: Local Film Gallery ("畫廊")
struct GalleryTabView: View {
    @ObservedObject private var store = LocalGalleryStore.shared
    var onEditImage: (UIImage) -> Void

    @State private var selectedItem: SavedPhotoItem?
    @State private var shareImage: UIImage?
    @State private var showShare = false

    private let cols = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("畫廊")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(store.items.count) 張相片")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)

                if store.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.28))
                        Text("仲未有膠片作品，去首頁影返張先！")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                } else {
                    LazyVGrid(columns: cols, spacing: 4) {
                        ForEach(store.items) { item in
                            if let img = store.loadImage(for: item) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minHeight: 118, maxHeight: 118)
                                    .clipped()
                                    .onTapGesture { selectedItem = item }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .sheet(item: $selectedItem) { item in
            if let img = store.loadImage(for: item) {
                NavigationStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("關閉") { selectedItem = nil }
                        }
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button {
                                shareImage = img
                                showShare = true
                            } label: {
                                Label("分享", systemImage: "square.and.arrow.up")
                            }
                            Spacer()
                            Button {
                                selectedItem = nil
                                onEditImage(img)
                            } label: {
                                Label("再修圖", systemImage: "slider.horizontal.3")
                            }
                            Spacer()
                            Button(role: .destructive) {
                                store.delete(item)
                                selectedItem = nil
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                    .sheet(isPresented: $showShare) {
                        if let shareImage { LumenShareSheet(items: [shareImage]) }
                    }
                }
            }
        }
    }
}

// MARK: - Full Photo Editor (Imported / Re-edited Photos)
struct PhotoEditorView: View {
    let sourceImage: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var adj: EditAdjustments
    @State private var previewImage: UIImage?
    @State private var editSection = 0 // 0=濾鏡, 1=調色, 2=膠片與邊框
    @State private var selectedCategory: FilmCategory = .kodak
    @State private var isSaving = false

    init(sourceImage: UIImage, initialAdj: EditAdjustments) {
        self.sourceImage = sourceImage.normalizedUp()
        _adj = State(initialValue: initialAdj)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    ZStack {
                        if let img = previewImage ?? Optional(sourceImage) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)

                    Picker("", selection: $editSection) {
                        Text("膠片濾鏡").tag(0)
                        Text("基礎調色").tag(1)
                        Text("邊框 / 質感").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        if editSection == 0 {
                            editorFilterSection
                        } else if editSection == 1 {
                            editorAdjustSection
                        } else {
                            editorEffectSection
                        }
                    }
                    .padding(16)
                    .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("膠片修圖")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "儲存中..." : "儲存") {
                        saveFinalPhoto()
                    }
                    .bold()
                    .disabled(isSaving)
                }
            }
            .onAppear {
                selectedCategory = adj.filter.category
                updatePreview()
            }
        }
    }

    private var editorFilterSection: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(FilmCategory.allCases) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat.rawValue)
                                .font(.system(size: 12, weight: selectedCategory == cat ? .bold : .regular))
                                .foregroundStyle(selectedCategory == cat ? Color.white : Color.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilmCatalog.recipes(in: selectedCategory)) { r in
                        let on = adj.filter.id == r.id
                        Button {
                            adj.filter = r
                            if adj.intensity < 1 { adj.intensity = 100 }
                            updatePreview()
                        } label: {
                            Text(r.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(on ? Color.black : Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(on ? Color.white : Color.white.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Text("強度").font(.caption).foregroundStyle(.white.opacity(0.7))
                Slider(value: $adj.intensity, in: 0...100, step: 1).tint(.white)
                    .onChange(of: adj.intensity) { _, _ in updatePreview() }
                Text("\(Int(adj.intensity))").font(.caption.monospaced()).frame(width: 28)
            }
        }
    }

    private var editorAdjustSection: some View {
        VStack(spacing: 10) {
            sliderRow("曝光", value: $adj.exposure, range: -2...2)
            sliderRow("對比", value: $adj.contrastShift, range: -1...1)
            sliderRow("飽和", value: $adj.saturationShift, range: -1...1)
            sliderRow("色溫", value: $adj.tempShift, range: -1...1)
        }
    }

    private var editorEffectSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(BorderStyle.allCases) { b in
                    let on = adj.border == b
                    Button {
                        adj.border = b
                        updatePreview()
                    } label: {
                        Text(b.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(on ? Color.black : Color.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(on ? Color.white : Color.white.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            sliderRow("顆粒", value: $adj.grain, range: 0...1)
            sliderRow("輝光", value: $adj.halation, range: 0...1)
            sliderRow("柔光", value: $adj.softGlow, range: 0...1)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 34, alignment: .leading)
            Slider(value: value, in: range)
                .tint(.white)
                .onChange(of: value.wrappedValue) { _, _ in updatePreview() }
        }
    }

    private func updatePreview() {
        let currentAdj = adj
        let small = Self.downscaleForPreview(sourceImage)
        DispatchQueue.global(qos: .userInitiated).async {
            let rendered = FilmPipeline.shared.renderUIImage(from: small, adj: currentAdj, aspect: nil, exif: CameraEXIF())
            DispatchQueue.main.async { previewImage = rendered }
        }
    }

    private func saveFinalPhoto() {
        isSaving = true
        let currentAdj = adj
        let full = sourceImage
        DispatchQueue.global(qos: .userInitiated).async {
            let rendered = FilmPipeline.shared.renderUIImage(from: full, adj: currentAdj, aspect: nil, exif: CameraEXIF())
            DispatchQueue.main.async {
                if let rendered {
                    LocalGalleryStore.shared.saveToGalleryAndPhotos(rendered, saveToSystemPhotos: true)
                }
                isSaving = false
                dismiss()
            }
        }
    }

    private static func downscaleForPreview(_ img: UIImage) -> UIImage {
        let maxSide: CGFloat = 1080
        let longest = max(img.size.width, img.size.height)
        guard longest > maxSide else { return img }
        let scale = maxSide / longest
        let sz = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        return UIGraphicsImageRenderer(size: sz).image { _ in
            img.draw(in: CGRect(origin: .zero, size: sz))
        }
    }
}
