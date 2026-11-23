import Foundation
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - Film Filter Categories & Recipes
enum FilmCategory: String, CaseIterable, Identifiable {
    case kodak = "柯達膠片模擬"
    case atmosphere = "膠片氛圍濾鏡"
    case fuji = "富士濾鏡"
    case highContrast = "高反差氛圍濾鏡"
    var id: String { rawValue }
}

struct FilmRecipe: Identifiable, Hashable {
    let id: String
    let name: String
    let category: FilmCategory
    let temp: Float          // 6500 neutral; >6500 cooler, <6500 warmer
    let tint: Float          // >0 magenta, <0 green
    let contrast: Float
    let saturation: Float
    let brightness: Float
    let highlightAmt: Float
    let shadowAmt: Float
    let rGain: Float
    let gGain: Float
    let bGain: Float
    let shadowBlue: Float
    let shadowWarm: Float
    let isMono: Bool
    let vignette: Float
    let previewColors: [String]
}

enum BorderStyle: String, CaseIterable, Identifiable {
    case none = "無邊框"
    case liquidGlass = "液態玻璃"
    case polaroid = "留白"
    case darkFrame = "暗黑畫框"
    var id: String { rawValue }
}

enum AspectMode: String, CaseIterable, Identifiable {
    case ratio34 = "3:4"
    case ratio11 = "1:1"
    case ratio169 = "9:16"
    var id: String { rawValue }
    var aspectValue: CGFloat {
        switch self {
        case .ratio34: return 3.0 / 4.0
        case .ratio11: return 1.0
        case .ratio169: return 9.0 / 16.0
        }
    }
}

struct HomePresetCard: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let filterID: String
    let border: BorderStyle
    let grain: Double
    let halation: Double
    let softGlow: Double
    let gradientHex: [String]
}

struct CameraEXIF {
    var deviceName: String = UIDevice.current.modelNameFriendly
    var focalLength: String = "24mm"
    var aperture: String = "f/1.8"
    var iso: String = "ISO 100"
    var shutter: String = "1/120s"
}

struct ColorTransferParams {
    var rGain: Float = 1.0
    var gGain: Float = 1.0
    var bGain: Float = 1.0
    var rBias: Float = 0.0
    var gBias: Float = 0.0
    var bBias: Float = 0.0
    var saturation: Float = 1.0
    var contrast: Float = 1.0
}

struct EditAdjustments {
    var filter: FilmRecipe = FilmCatalog.all[0]
    var intensity: Double = 100.0
    var border: BorderStyle = .none
    var grain: Double = 0.20
    var halation: Double = 0.0
    var softGlow: Double = 0.0
    var toneX: Double = 0.0      // 2D Pad X: -1 cool ... +1 warm
    var toneY: Double = 0.0      // 2D Pad Y: -1 soft ... +1 contrast/vibrant
    var exposure: Double = 0.0
    var contrastShift: Double = 0.0
    var saturationShift: Double = 0.0
    var tempShift: Double = 0.0
    var aiTransfer: ColorTransferParams? = nil
    var aiStrength: Double = 0.0
}

// MARK: - Complete 16 Film Catalog
enum FilmCatalog {
    static let all: [FilmRecipe] = [
        // 柯達膠片模擬
        FilmRecipe(id: "portra", name: "Portra", category: .kodak, temp: 6000, tint: 6, contrast: 1.04, saturation: 0.94, brightness: 0.03, highlightAmt: 0.90, shadowAmt: 0.22, rGain: 1.03, gGain: 1.00, bGain: 0.95, shadowBlue: 0.01, shadowWarm: 0.018, isMono: false, vignette: 0.25, previewColors: ["D8A878", "6F8998"]),
        FilmRecipe(id: "800t", name: "800T", category: .kodak, temp: 7600, tint: -8, contrast: 1.12, saturation: 1.08, brightness: -0.02, highlightAmt: 0.85, shadowAmt: 0.14, rGain: 0.96, gGain: 1.02, bGain: 1.10, shadowBlue: 0.035, shadowWarm: 0.0, isMono: false, vignette: 0.45, previewColors: ["1C4D5C", "E86A33"]),
        FilmRecipe(id: "gold200", name: "Gold 200", category: .kodak, temp: 5600, tint: 4, contrast: 1.08, saturation: 1.06, brightness: 0.02, highlightAmt: 0.92, shadowAmt: 0.18, rGain: 1.06, gGain: 1.01, bGain: 0.91, shadowBlue: 0.0, shadowWarm: 0.028, isMono: false, vignette: 0.30, previewColors: ["E0A94F", "5B4833"]),
        FilmRecipe(id: "ektar100", name: "Ektar 100", category: .kodak, temp: 6200, tint: 8, contrast: 1.16, saturation: 1.24, brightness: 0.00, highlightAmt: 0.95, shadowAmt: 0.10, rGain: 1.07, gGain: 0.99, bGain: 1.02, shadowBlue: 0.015, shadowWarm: 0.01, isMono: false, vignette: 0.35, previewColors: ["C44536", "284B63"]),

        // 膠片氛圍濾鏡
        FilmRecipe(id: "film003", name: "FILM003", category: .atmosphere, temp: 6150, tint: -6, contrast: 1.06, saturation: 0.90, brightness: 0.02, highlightAmt: 0.88, shadowAmt: 0.25, rGain: 1.01, gGain: 1.03, bGain: 0.96, shadowBlue: 0.018, shadowWarm: 0.012, isMono: false, vignette: 0.30, previewColors: ["A39E8A", "4A5B56"]),
        FilmRecipe(id: "liquid", name: "Aqua Glass", category: .atmosphere, temp: 7200, tint: -10, contrast: 1.05, saturation: 1.12, brightness: 0.03, highlightAmt: 0.88, shadowAmt: 0.20, rGain: 0.92, gGain: 1.05, bGain: 1.10, shadowBlue: 0.03, shadowWarm: 0.0, isMono: false, vignette: 0.20, previewColors: ["1282A2", "72DFEE"]),
        FilmRecipe(id: "dusk", name: "Warm Dusk", category: .atmosphere, temp: 5400, tint: 12, contrast: 1.06, saturation: 1.02, brightness: 0.01, highlightAmt: 0.86, shadowAmt: 0.20, rGain: 1.08, gGain: 0.97, bGain: 0.94, shadowBlue: 0.01, shadowWarm: 0.03, isMono: false, vignette: 0.35, previewColors: ["D67A61", "4A354D"]),
        FilmRecipe(id: "mist", name: "Airy Mist", category: .atmosphere, temp: 6900, tint: -4, contrast: 0.94, saturation: 0.86, brightness: 0.06, highlightAmt: 0.82, shadowAmt: 0.32, rGain: 0.97, gGain: 1.01, bGain: 1.04, shadowBlue: 0.025, shadowWarm: 0.0, isMono: false, vignette: 0.15, previewColors: ["9DB8C4", "DCE4E8"]),

        // 富士濾鏡
        FilmRecipe(id: "classic_neg", name: "Classic Neg", category: .fuji, temp: 6600, tint: -12, contrast: 1.16, saturation: 0.88, brightness: -0.01, highlightAmt: 0.90, shadowAmt: 0.12, rGain: 1.04, gGain: 1.03, bGain: 0.93, shadowBlue: 0.02, shadowWarm: 0.015, isMono: false, vignette: 0.35, previewColors: ["3D5E57", "C76D52"]),
        FilmRecipe(id: "classic_chrome", name: "Chrome", category: .fuji, temp: 6750, tint: -5, contrast: 1.10, saturation: 0.80, brightness: 0.00, highlightAmt: 0.88, shadowAmt: 0.15, rGain: 0.99, gGain: 1.01, bGain: 0.98, shadowBlue: 0.02, shadowWarm: 0.0, isMono: false, vignette: 0.28, previewColors: ["627682", "B5A694"]),
        FilmRecipe(id: "velvia", name: "Velvia 50", category: .fuji, temp: 6350, tint: 10, contrast: 1.18, saturation: 1.32, brightness: -0.01, highlightAmt: 0.96, shadowAmt: 0.08, rGain: 1.06, gGain: 1.02, bGain: 1.05, shadowBlue: 0.01, shadowWarm: 0.01, isMono: false, vignette: 0.35, previewColors: ["1E824C", "2E6DA4"]),
        FilmRecipe(id: "pro400h", name: "Pro 400H", category: .fuji, temp: 6850, tint: -9, contrast: 0.98, saturation: 0.92, brightness: 0.04, highlightAmt: 0.84, shadowAmt: 0.28, rGain: 0.96, gGain: 1.04, bGain: 1.02, shadowBlue: 0.02, shadowWarm: 0.0, isMono: false, vignette: 0.18, previewColors: ["7FB2A8", "E8DDD0"]),

        // 高反差氛圍濾鏡
        FilmRecipe(id: "ricoh_pos", name: "理光正片", category: .highContrast, temp: 6400, tint: 4, contrast: 1.24, saturation: 1.16, brightness: -0.03, highlightAmt: 0.94, shadowAmt: 0.05, rGain: 1.05, gGain: 1.00, bGain: 1.04, shadowBlue: 0.02, shadowWarm: 0.0, isMono: false, vignette: 0.55, previewColors: ["1881B8", "335C2D"]),
        FilmRecipe(id: "ricoh_neg", name: "GR 負片", category: .highContrast, temp: 6700, tint: -6, contrast: 1.20, saturation: 0.86, brightness: -0.02, highlightAmt: 0.90, shadowAmt: 0.08, rGain: 1.01, gGain: 1.02, bGain: 0.96, shadowBlue: 0.025, shadowWarm: 0.0, isMono: false, vignette: 0.48, previewColors: ["3C4B52", "9E8D78"]),
        FilmRecipe(id: "noir400", name: "森山黑白", category: .highContrast, temp: 6500, tint: 0, contrast: 1.42, saturation: 0.0, brightness: -0.03, highlightAmt: 0.95, shadowAmt: 0.04, rGain: 1.0, gGain: 1.0, bGain: 1.0, shadowBlue: 0.0, shadowWarm: 0.0, isMono: true, vignette: 0.65, previewColors: ["1A1A1A", "BDBDBD"]),
        FilmRecipe(id: "street_hard", name: "暗夜街頭", category: .highContrast, temp: 7100, tint: 6, contrast: 1.28, saturation: 1.10, brightness: -0.05, highlightAmt: 0.92, shadowAmt: 0.04, rGain: 1.04, gGain: 0.97, bGain: 1.08, shadowBlue: 0.03, shadowWarm: 0.0, isMono: false, vignette: 0.60, previewColors: ["151D3B", "D82148"])
    ]

    static func recipes(in category: FilmCategory) -> [FilmRecipe] {
        all.filter { $0.category == category }
    }

    static func find(_ id: String) -> FilmRecipe {
        all.first { $0.id == id } ?? all[0]
    }

    static let homePresets: [HomePresetCard] = [
        HomePresetCard(id: "cine800t", title: "Cine 800T", subtitle: "濾鏡 · 顆粒 · 輝光 · 柔光", filterID: "800t", border: .none, grain: 0.35, halation: 0.65, softGlow: 0.35, gradientHex: ["09141C", "163A47", "D65A31"]),
        HomePresetCard(id: "polaroid", title: "留白", subtitle: "濾鏡 · 邊框 · 顆粒 · 柔光", filterID: "film003", border: .polaroid, grain: 0.25, halation: 0.0, softGlow: 0.20, gradientHex: ["104E75", "1F86A8", "9AD1D4"]),
        HomePresetCard(id: "glass", title: "液態玻璃", subtitle: "濾鏡 · 邊框 · 顆粒 · 柔光", filterID: "liquid", border: .liquidGlass, grain: 0.18, halation: 0.0, softGlow: 0.25, gradientHex: ["0A3A4A", "127488", "68D8E6"]),
        HomePresetCard(id: "ricoh", title: "理光", subtitle: "濾鏡 · 邊框 · 顆粒 · 柔光", filterID: "ricoh_pos", border: .liquidGlass, grain: 0.28, halation: 0.15, softGlow: 0.15, gradientHex: ["1789C6", "48B4E0", "4E5B31"])
    ]
}

// MARK: - CoreImage Real-Time Film Pipeline
final class FilmPipeline {
    static let shared = FilmPipeline()
    let context = CIContext(options: [.useSoftwareRenderer: false, .priorityRequestLow: false])

    func process(ciImage input: CIImage, adj: EditAdjustments, isPreview: Bool) -> CIImage {
        let extent = input.extent
        var current = input

        // 1. Base Exposure / Manual Edits
        if abs(adj.exposure) > 0.01 {
            let exp = CIFilter.exposureAdjust()
            exp.inputImage = current
            exp.ev = Float(adj.exposure)
            current = exp.outputImage ?? current
        }

        // 2. Apply Film Recipe
        var styled = applyRecipe(current, recipe: adj.filter)

        // 3. Apply 2D Tone Pad & Manual Shifts
        let totalTemp = Float(adj.toneX * -1400.0 + adj.tempShift * -1600.0)
        if abs(totalTemp) > 20 {
            let t = CIFilter.temperatureAndTint()
            t.inputImage = styled
            t.neutral = CIVector(x: CGFloat(6500.0 + totalTemp), y: 0)
            t.targetNeutral = CIVector(x: 6500, y: 0)
            styled = t.outputImage ?? styled
        }

        let extraContrast = Float(1.0 + adj.toneY * 0.22 + adj.contrastShift * 0.35)
        let extraSat = Float(1.0 + adj.toneY * 0.16 + adj.saturationShift * 0.50)
        if abs(extraContrast - 1.0) > 0.01 || abs(extraSat - 1.0) > 0.01 {
            let cc = CIFilter.colorControls()
            cc.inputImage = styled
            cc.contrast = extraContrast
            cc.saturation = adj.filter.isMono ? 0 : max(0, extraSat)
            styled = cc.outputImage ?? styled
        }

        // 4. AI Color Transfer (Offline Reference Match)
        if let ai = adj.aiTransfer, adj.aiStrength > 0.01 {
            let mat = CIFilter.colorMatrix()
            mat.inputImage = styled
            mat.rVector = CIVector(x: CGFloat(ai.rGain), y: 0, z: 0, w: 0)
            mat.gVector = CIVector(x: 0, y: CGFloat(ai.gGain), z: 0, w: 0)
            mat.bVector = CIVector(x: 0, y: 0, z: CGFloat(ai.bGain), w: 0)
            mat.biasVector = CIVector(x: CGFloat(ai.rBias), y: CGFloat(ai.gBias), z: CGFloat(ai.bBias), w: 0)
            if let aiOut = mat.outputImage {
                let cc = CIFilter.colorControls()
                cc.inputImage = aiOut
                cc.contrast = ai.contrast
                cc.saturation = ai.saturation
                let matched = cc.outputImage ?? aiOut
                styled = blend(base: styled, target: matched, amount: Float(adj.aiStrength))
            }
        }

        // 5. Intensity 0-100 Blend
        let strength = Float(max(0, min(100, adj.intensity)) / 100.0)
        var out = strength < 0.99 ? blend(base: current, target: styled, amount: strength) : styled

        // 6. Soft Glow (Pro-Mist 柔光)
        if adj.softGlow > 0.02 {
            let bloom = CIFilter.bloom()
            bloom.inputImage = out
            bloom.intensity = Float(adj.softGlow * 0.75)
            bloom.radius = isPreview ? 10.0 : 28.0
            if let bOut = bloom.outputImage?.cropped(to: extent) {
                out = bOut
            }
        }

        // 7. Film Halation (800T 紅橙膠片輝光)
        if adj.halation > 0.02 {
            out = applyHalation(out, extent: extent, strength: Float(adj.halation), isPreview: isPreview)
        }

        // 8. Film Grain (顆粒)
        if adj.grain > 0.02 {
            out = applyGrain(out, extent: extent, strength: Float(adj.grain))
        }

        return out.cropped(to: extent)
    }

    private func applyRecipe(_ input: CIImage, recipe: FilmRecipe) -> CIImage {
        var img = input

        if recipe.isMono {
            let mono = CIFilter.photoEffectNoir()
            mono.inputImage = img
            img = mono.outputImage ?? img
        } else {
            let temp = CIFilter.temperatureAndTint()
            temp.inputImage = img
            temp.neutral = CIVector(x: CGFloat(recipe.temp), y: CGFloat(recipe.tint))
            temp.targetNeutral = CIVector(x: 6500, y: 0)
            img = temp.outputImage ?? img

            let mat = CIFilter.colorMatrix()
            mat.inputImage = img
            mat.rVector = CIVector(x: CGFloat(recipe.rGain), y: 0, z: 0, w: 0)
            mat.gVector = CIVector(x: 0, y: CGFloat(recipe.gGain), z: 0, w: 0)
            mat.bVector = CIVector(x: 0, y: 0, z: CGFloat(recipe.bGain), w: 0)
            mat.biasVector = CIVector(x: CGFloat(recipe.shadowWarm), y: CGFloat(recipe.shadowWarm * 0.4), z: CGFloat(recipe.shadowBlue), w: 0)
            img = mat.outputImage ?? img
        }

        let hs = CIFilter.highlightShadowAdjust()
        hs.inputImage = img
        hs.highlightAmount = recipe.highlightAmt
        hs.shadowAmount = recipe.shadowAmt
        img = hs.outputImage ?? img

        let cc = CIFilter.colorControls()
        cc.inputImage = img
        cc.contrast = recipe.contrast
        cc.saturation = recipe.isMono ? 0 : recipe.saturation
        cc.brightness = recipe.brightness
        img = cc.outputImage ?? img

        if recipe.vignette > 0.05 {
            let vig = CIFilter.vignette()
            vig.inputImage = img
            vig.intensity = recipe.vignette
            vig.radius = 1.6
            img = vig.outputImage ?? img
        }

        return img
    }

    private func applyHalation(_ input: CIImage, extent: CGRect, strength: Float, isPreview: Bool) -> CIImage {
        let bright = CIFilter.colorMatrix()
        bright.inputImage = input
        bright.rVector = CIVector(x: 2.2, y: 0, z: 0, w: 0)
        bright.gVector = CIVector(x: 0, y: 2.2, z: 0, w: 0)
        bright.bVector = CIVector(x: 0, y: 0, z: 2.2, w: 0)
        bright.biasVector = CIVector(x: -1.35, y: -1.35, z: -1.35, w: 0)

        let clamp = CIFilter.colorClamp()
        clamp.inputImage = bright.outputImage
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)

        let tintRed = CIFilter.colorMatrix()
        tintRed.inputImage = clamp.outputImage
        tintRed.rVector = CIVector(x: CGFloat(1.0 * strength), y: 0, z: 0, w: 0)
        tintRed.gVector = CIVector(x: 0, y: CGFloat(0.28 * strength), z: 0, w: 0)
        tintRed.bVector = CIVector(x: 0, y: 0, z: CGFloat(0.06 * strength), w: 0)

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = tintRed.outputImage
        blur.radius = isPreview ? 12.0 : 34.0

        let screen = CIFilter.screenBlendMode()
        screen.inputImage = blur.outputImage?.cropped(to: extent)
        screen.backgroundImage = input
        return screen.outputImage?.cropped(to: extent) ?? input
    }

    private func applyGrain(_ input: CIImage, extent: CGRect, strength: Float) -> CIImage {
        let noise = CIFilter.randomGenerator().outputImage?.cropped(to: extent)
        let mono = CIFilter.colorControls()
        mono.inputImage = noise
        mono.saturation = 0
        mono.contrast = 1.4

        let alpha = CIFilter.colorMatrix()
        alpha.inputImage = mono.outputImage
        alpha.aVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(strength * 0.24))

        let comp = CIFilter.softLightBlendMode()
        comp.inputImage = alpha.outputImage
        comp.backgroundImage = input
        return comp.outputImage?.cropped(to: extent) ?? input
    }

    private func blend(base: CIImage, target: CIImage, amount: Float) -> CIImage {
        let dis = CIFilter.dissolveTransition()
        dis.inputImage = base
        dis.targetImage = target
        dis.time = amount
        return dis.outputImage ?? target
    }

    func renderUIImage(from source: UIImage, adj: EditAdjustments, aspect: AspectMode?, exif: CameraEXIF) -> UIImage? {
        let upright = source.normalizedUp()
        guard let cg = upright.cgImage else { return nil }
        var ci = CIImage(cgImage: cg)

        if let aspect {
            ci = cropToAspect(ci, ratio: aspect.aspectValue)
        }

        let processed = process(ciImage: ci, adj: adj, isPreview: false)
        guard let outCG = context.createCGImage(processed, from: processed.extent) else { return nil }
        let baseImg = UIImage(cgImage: outCG)

        if adj.border == .none {
            return baseImg
        }
        return BorderComposer.compose(photo: baseImg, style: adj.border, exif: exif)
    }

    func cropToAspect(_ img: CIImage, ratio: CGFloat) -> CIImage {
        let ext = img.extent
        let curRatio = ext.width / max(1, ext.height)
        var target = ext
        if curRatio > ratio {
            let newW = ext.height * ratio
            target = CGRect(x: ext.midX - newW / 2, y: ext.minY, width: newW, height: ext.height)
        } else {
            let newH = ext.width / ratio
            target = CGRect(x: ext.minX, y: ext.midY - newH / 2, width: ext.width, height: newH)
        }
        return img.cropped(to: target)
    }
}

// MARK: - Offline AI Color Transfer (智能仿色)
enum AIColorMatcher {
    static func analyze(source: UIImage, reference: UIImage) -> ColorTransferParams {
        let s = stats(of: source)
        let r = stats(of: reference)
        func safeGain(_ refStd: Float, _ srcStd: Float) -> Float {
            max(0.65, min(1.45, refStd / max(0.05, srcStd)))
        }
        let rg = safeGain(r.stdR, s.stdR)
        let gg = safeGain(r.stdG, s.stdG)
        let bg = safeGain(r.stdB, s.stdB)
        let rb = max(-0.22, min(0.22, r.meanR - s.meanR * rg))
        let gb = max(-0.22, min(0.22, r.meanG - s.meanG * gg))
        let bb = max(-0.22, min(0.22, r.meanB - s.meanB * bg))
        return ColorTransferParams(
            rGain: rg, gGain: gg, bGain: bg,
            rBias: rb, gBias: gb, bBias: bb,
            saturation: max(0.65, min(1.35, r.sat / max(0.1, s.sat))),
            contrast: 1.04
        )
    }

    private static func stats(of image: UIImage) -> (meanR: Float, meanG: Float, meanB: Float, stdR: Float, stdG: Float, stdB: Float, sat: Float) {
        let side = 48
        var buf = [UInt8](repeating: 0, count: side * side * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let cg = image.cgImage,
              let ctx = CGContext(data: &buf, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return (0.5, 0.5, 0.5, 0.2, 0.2, 0.2, 0.3)
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        let n = Float(side * side)
        var sr: Float = 0, sg: Float = 0, sb: Float = 0, ssat: Float = 0
        for i in stride(from: 0, to: buf.count, by: 4) {
            let r = Float(buf[i]) / 255, g = Float(buf[i + 1]) / 255, b = Float(buf[i + 2]) / 255
            sr += r; sg += g; sb += b
            ssat += (max(r, max(g, b)) - min(r, min(g, b)))
        }
        let mr = sr / n, mg = sg / n, mb = sb / n
        var vr: Float = 0, vg: Float = 0, vb: Float = 0
        for i in stride(from: 0, to: buf.count, by: 4) {
            let dr = Float(buf[i]) / 255 - mr, dg = Float(buf[i + 1]) / 255 - mg, db = Float(buf[i + 2]) / 255 - mb
            vr += dr * dr; vg += dg * dg; vb += db * db
        }
        return (mr, mg, mb, sqrt(vr / n), sqrt(vg / n), sqrt(vb / n), ssat / n)
    }
}

// MARK: - High-Res Border & EXIF Watermark Composer
enum BorderComposer {
    static func compose(photo: UIImage, style: BorderStyle, exif: CameraEXIF) -> UIImage {
        let w = photo.size.width
        let h = photo.size.height
        let sidePad = w * 0.065
        let topPad = w * 0.065
        let bottomPad = w * 0.22
        let canvasSize = CGSize(width: w + sidePad * 2, height: h + topPad + bottomPad)
        let photoRect = CGRect(x: sidePad, y: topPad, width: w, height: h)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { ctx in
            let cgCtx = ctx.cgContext
            switch style {
            case .liquidGlass:
                if let ci = CIImage(image: photo) {
                    let blur = CIFilter.gaussianBlur()
                    blur.inputImage = ci.clampedToExtent()
                    blur.radius = Float(w * 0.055)
                    if let out = blur.outputImage?.cropped(to: ci.extent),
                       let bgCG = FilmPipeline.shared.context.createCGImage(out, from: out.extent) {
                        UIImage(cgImage: bgCG).draw(in: CGRect(origin: .zero, size: canvasSize))
                    }
                }
                UIColor.white.withAlphaComponent(0.14).setFill()
                cgCtx.fill(CGRect(origin: .zero, size: canvasSize))

                cgCtx.saveGState()
                cgCtx.setShadow(offset: CGSize(width: 0, height: w * 0.018), blur: w * 0.045, color: UIColor.black.withAlphaComponent(0.38).cgColor)
                let clipPath = UIBezierPath(roundedRect: photoRect, cornerRadius: w * 0.04)
                UIColor.black.setFill()
                clipPath.fill()
                cgCtx.restoreGState()

                cgCtx.saveGState()
                clipPath.addClip()
                photo.draw(in: photoRect)
                cgCtx.restoreGState()

                drawWatermark(in: CGRect(x: sidePad, y: topPad + h, width: w, height: bottomPad), exif: exif, textColor: .white.withAlphaComponent(0.92), subColor: .white.withAlphaComponent(0.72))

            case .polaroid:
                UIColor(white: 0.98, alpha: 1).setFill()
                cgCtx.fill(CGRect(origin: .zero, size: canvasSize))
                photo.draw(in: photoRect)
                drawWatermark(in: CGRect(x: sidePad, y: topPad + h, width: w, height: bottomPad), exif: exif, textColor: UIColor(white: 0.12, alpha: 1), subColor: UIColor(white: 0.45, alpha: 1))

            case .darkFrame:
                UIColor(white: 0.07, alpha: 1).setFill()
                cgCtx.fill(CGRect(origin: .zero, size: canvasSize))
                photo.draw(in: photoRect)
                drawWatermark(in: CGRect(x: sidePad, y: topPad + h, width: w, height: bottomPad), exif: exif, textColor: .white.withAlphaComponent(0.92), subColor: .white.withAlphaComponent(0.55))

            case .none:
                photo.draw(in: CGRect(origin: .zero, size: canvasSize))
            }
        }
    }

    private static func drawWatermark(in rect: CGRect, exif: CameraEXIF, textColor: UIColor, subColor: UIColor) {
        let titleFont = UIFont.systemFont(ofSize: rect.width * 0.034, weight: .semibold)
        let subFont = UIFont.monospacedDigitSystemFont(ofSize: rect.width * 0.024, weight: .medium)
        let style = NSMutableParagraphStyle(); style.alignment = .center

        let title = "Shot on \(exif.deviceName)"
        let sub = "\(exif.focalLength)  \(exif.aperture)  \(exif.iso)  \(exif.shutter)"

        let tSize = title.size(withAttributes: [.font: titleFont])
        let sSize = sub.size(withAttributes: [.font: subFont])
        let totalH = tSize.height + sSize.height + rect.height * 0.07
        let startY = rect.minY + (rect.height - totalH) / 2

        title.draw(in: CGRect(x: rect.minX, y: startY, width: rect.width, height: tSize.height + 4),
                   withAttributes: [.font: titleFont, .foregroundColor: textColor, .paragraphStyle: style])
        sub.draw(in: CGRect(x: rect.minX, y: startY + tSize.height + rect.height * 0.06, width: rect.width, height: sSize.height + 4),
                 withAttributes: [.font: subFont, .foregroundColor: subColor, .paragraphStyle: style])
    }
}

// MARK: - Helpers
extension UIImage {
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat(); format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension UIDevice {
    var modelNameFriendly: String {
        var sys = utsname(); uname(&sys)
        let id = withUnsafePointer(to: &sys.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingUTF8: $0) ?? "iPhone" }
        }
        let map: [String: String] = [
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus"
        ]
        return map[id] ?? "iPhone"
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&v)
        if clean.count == 6 {
            self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
        } else {
            self.init(white: 0.4)
        }
    }
}
