// 換 App icon 底色／圖形色，不動構圖（macOS 內建 swift，無外部相依）。
// 用法：
//   swift tool/recolor_app_icon.swift sample <in.png> <x> <y>
//   swift tool/recolor_app_icon.swift bg    <in.png> <out.png> <#RRGGBB>   # Default：底色換新色，圖形不變
//   swift tool/recolor_app_icon.swift glyph <in.png> <out.png> <#RRGGBB>   # Dark：圖形色換新色，底色不變
// 抗鋸齒邊緣是「底色與圖形色的線性混合」，所以逐像素反推混合比例再用新端點重混，邊緣才不會留舊色暈。
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func hex(_ s: String) -> [Double] {
  let h = s.replacingOccurrences(of: "#", with: "")
  let v = UInt32(h, radix: 16)!
  return [Double((v >> 16) & 255), Double((v >> 8) & 255), Double(v & 255)]
}
func load(_ path: String) -> (CGImage, [UInt8], Int, Int) {
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
  let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
  let w = img.width, h = img.height
  var buf = [UInt8](repeating: 0, count: w * h * 4)
  let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
  return (img, buf, w, h)
}
func px(_ b: [UInt8], _ w: Int, _ x: Int, _ y: Int) -> [Double] {
  let i = (y * w + x) * 4
  return [Double(b[i]), Double(b[i + 1]), Double(b[i + 2])]
}
let a = CommandLine.arguments
if a[1] == "sample" {
  let (_, b, w, _) = load(a[2])
  let p = px(b, w, Int(a[3])!, Int(a[4])!).map { Int($0) }
  print(String(format: "#%02X%02X%02X", p[0], p[1], p[2]))
  exit(0)
}
var (_, buf, w, h) = load(a[2])
let bg = px(buf, w, 0, 0)
let ring = px(buf, w, 210, 420) // 定位針外框左側中段，永遠落在圖形色上
let target = hex(a[4])
let (c0, c1, n0, n1): ([Double], [Double], [Double], [Double]) =
  a[1] == "bg" ? (bg, ring, target, ring) : (bg, ring, bg, target)
let k = (0..<3).max { abs(c1[$0] - c0[$0]) < abs(c1[$1] - c0[$1]) }!
for y in 0..<h { for x in 0..<w {
  let p = px(buf, w, x, y)
  let t = min(1, max(0, (p[k] - c0[k]) / (c1[k] - c0[k])))
  let i = (y * w + x) * 4
  for c in 0..<3 { buf[i + c] = UInt8((n0[c] + t * (n1[c] - n0[c])).rounded()) }
} }
let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[3]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
