// ocr_vision.swift: OCR images with the macOS Vision framework (local, no network).
// Usage: ocr_vision a.png b.png ...   Prints "@@@PAGE <path>" then the recognized lines, per image.
// Many images per call because starting Vision takes about a minute.
import Foundation
import Vision
import AppKit

for path in CommandLine.arguments.dropFirst() {
    print("@@@PAGE \(path)")
    guard let img = NSImage(contentsOfFile: path),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = true
    try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
    for o in (req.results ?? []) { if let t = o.topCandidates(1).first { print(t.string) } }
}
