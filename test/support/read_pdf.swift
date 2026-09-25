// 以 macOS 公開 PDFKit 檢查真正 PDF 的文字與連結；可選擇逐頁繪圖供目視驗證。
import AppKit
import PDFKit

let source = URL(fileURLWithPath: CommandLine.arguments[1])
guard let document = PDFDocument(url: source) else { fatalError("PDF 無法開啟") }
var pages: [String] = []
var links: [String] = []
for index in 0..<document.pageCount {
    guard let page = document.page(at: index) else { fatalError("PDF 缺頁") }
    pages.append(page.string ?? "")
    links += page.annotations.compactMap { $0.url?.absoluteString }
    if CommandLine.arguments.count > 2 {
        let image = page.thumbnail(of: NSSize(width: 1190, height: 1684), for: .mediaBox)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("PDF 頁面無法繪圖")
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
            .appendingPathComponent("page-\(index + 1).png")
        try png.write(to: output)
    }
}
let json = try JSONSerialization.data(withJSONObject: ["pages": pages, "links": links])
FileHandle.standardOutput.write(json)
