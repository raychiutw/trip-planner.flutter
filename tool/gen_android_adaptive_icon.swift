// 由 iOS Default 母圖產生 Android adaptive icon 的前景與 monochrome 圖層（macOS 內建 swift，無外部相依）。
// 用法：swift tool/gen_android_adaptive_icon.swift
// 做法：與 recolor_app_icon.swift 同一套反推——母圖每個像素是「底色與圖形色」的線性混合，
// 混合比例直接當 alpha，就得到透明底的圖形；圖形色取米白 #FFFBF5（前景）與白（monochrome，系統只看 alpha）。
// 圖形整體縮放並置中，使最遠的圖形像素落在 adaptive icon 安全區（66dp／108dp 的圓）內再留一點邊。
// 底層色 #8A6038 不在這裡產生，見 res/values/ic_launcher_background.xml。
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let master = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
let res = "android/app/src/main/res"
let densities: [(String, Int)] = [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]
let fitRadius = 31.0 / 108.0 // 安全區半徑是 33/108，留 2dp 邊給抗鋸齒

let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: master) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height
var buf = [UInt8](repeating: 0, count: w * h * 4)
CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  .draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
func px(_ x: Int, _ y: Int) -> [Double] { let i = (y * w + x) * 4; return [Double(buf[i]), Double(buf[i+1]), Double(buf[i+2])] }
let bg = px(0, 0), ring = px(210, 420) // 與 recolor_app_icon.swift 同一組取樣點
let k = (0..<3).max { abs(ring[$0] - bg[$0]) < abs(ring[$1] - bg[$1]) }!

// 逐像素 alpha（以母圖座標，y 向下）與圖形外接框
var alpha = [Double](repeating: 0, count: w * h)
var minX = w, maxX = 0, minY = h, maxY = 0
for y in 0..<h { for x in 0..<w {
  let t = min(1, max(0, (px(x, y)[k] - bg[k]) / (ring[k] - bg[k])))
  alpha[y * w + x] = t
  if t > 0.5 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
} }
let cx = Double(minX + maxX + 1) / 2, cy = Double(minY + maxY + 1) / 2
var far = 0.0
for y in 0..<h { for x in 0..<w where alpha[y * w + x] > 0.02 {
  far = max(far, hypot(Double(x) + 0.5 - cx, Double(y) + 0.5 - cy))
} }

func layer(_ color: [Double], size: Int) -> CGImage {
  // 先以 premultiplied 建母圖尺寸的圖形圖層，再用高品質插值縮放到目標尺寸
  var pm = [UInt8](repeating: 0, count: w * h * 4)
  for i in 0..<(w * h) {
    let a = alpha[i]
    for c in 0..<3 { pm[i * 4 + c] = UInt8((color[c] * a).rounded()) }
    pm[i * 4 + 3] = UInt8((a * 255).rounded())
  }
  let full = CGContext(data: &pm, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
  let s = Double(size) * fitRadius / far
  let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.interpolationQuality = .high
  // CGContext 原點在左下；母圖座標 y 向下，所以以 (h - cy) 換算中心
  ctx.draw(full, in: CGRect(x: Double(size) / 2 - cx * s, y: Double(size) / 2 - (Double(h) - cy) * s,
    width: Double(w) * s, height: Double(h) * s))
  return ctx.makeImage()!
}
func write(_ image: CGImage, _ path: String) {
  let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(d, image, nil)
  CGImageDestinationFinalize(d)
}
for (name, size) in densities {
  write(layer(ring, size: size), "\(res)/mipmap-\(name)/ic_launcher_foreground.png")
  write(layer([255, 255, 255], size: size), "\(res)/mipmap-\(name)/ic_launcher_monochrome.png")
}
print("done, 圖形最遠半徑 \(far)px／母圖 \(w)px")
