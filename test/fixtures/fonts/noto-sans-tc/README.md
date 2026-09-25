# PDF 字型驗證素材

兩個 TTF 是 `printing 5.14.3` 的 `PdfGoogleFonts.notoSansTCRegular`／`notoSansTCBold` 使用的未修改原檔；來源 URL、大小與 SHA-256 見 `manifest.json`，授權見 `OFL.txt`。保留完整字型以驗證正式字型的中文、字重及換行，不用拉丁字型或系統字型替代。

測試從既有 `PdfBaseCache.defaultCache` 公開 seam 供應這兩個固定 key，不改 production 字型 API，也不連線下載。macOS 以 PDFKit 抽取真正 PDF 的文字與 annotation；Ubuntu CI 安裝 `poppler-utils`，使用 `pdftotext` 與 `pdfinfo -url` 執行相同內容斷言，工具缺漏會失敗而非跳過。
