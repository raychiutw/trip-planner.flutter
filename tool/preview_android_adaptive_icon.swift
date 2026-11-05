// 靜態預覽：把前景疊在底色上，套圓形與圓角方形遮罩（模擬，不是啟動器實拍），並排輸出 PNG。
// 用法：swift tool/preview_android_adaptive_icon.swift [out.png]
// 右側是 monochrome 圖層套在淡棕圓底上，近似 Android 13 主題圖示（實際配色由系統決定）。
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let res = "android/app/src/main/res/mipmap-xxxhdpi"
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/qa/android-adaptive-icon-preview.png"
func load(_ n: String) -> CGImage {
  CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: "\(res)/\(n).png") as CFURL, nil)!, 0, nil)!
}
let fg = load("ic_launcher_foreground"), mono = load("ic_launcher_monochrome")
let cell = 432, pad = 40
let ctx = CGContext(data: nil, width: pad + 3 * (cell + pad), height: cell + 2 * pad, bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.93, blue: 0.93, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
func draw(_ i: Int, round: Bool, bg: CGColor, layer: CGImage, tintLayer: CGColor? = nil) {
  // 可見區是 108dp 中央 72dp 的遮罩（66dp 是安全區），遮罩直徑取 72/108
  let r = CGRect(x: pad + i * (cell + pad), y: pad, width: cell, height: cell)
  let m = CGFloat(cell) * 72 / 108, mr = CGRect(x: r.midX - m / 2, y: r.midY - m / 2, width: m, height: m)
  ctx.saveGState()
  ctx.addPath(CGPath(roundedRect: mr, cornerWidth: round ? m / 2 : m * 0.28, cornerHeight: round ? m / 2 : m * 0.28, transform: nil)); ctx.clip()
  ctx.setFillColor(bg); ctx.fill(r)
  if let t = tintLayer { ctx.clip(to: r, mask: layer); ctx.setFillColor(t); ctx.fill(r) } else { ctx.draw(layer, in: r) }
  ctx.restoreGState()
}
let brown = CGColor(srgbRed: 0x8A / 255.0, green: 0x60 / 255.0, blue: 0x38 / 255.0, alpha: 1)
draw(0, round: true, bg: brown, layer: fg)
draw(1, round: false, bg: brown, layer: fg)
draw(2, round: true, bg: CGColor(srgbRed: 0.91, green: 0.85, blue: 0.78, alpha: 1), layer: mono, tintLayer: CGColor(srgbRed: 0.35, green: 0.22, blue: 0.1, alpha: 1))
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, ctx.makeImage()!, nil); CGImageDestinationFinalize(d)
