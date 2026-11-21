import UIKit

/// 快门按下瞬间的水印快照。每次拍照都创建独立实例，避免异步处理导致水印错乱。
struct WatermarkSnapshot {
    let timeText: String
    let note: String
}

enum WatermarkRenderer {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter
    }()

    static func format(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// 将水印按最终照片的实际像素尺寸等比例合成到左下角，保持原始分辨率与长宽比。
    static func render(image: UIImage, snapshot: WatermarkSnapshot) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { context in
            let cg = context.cgContext
            let w = image.size.width
            let h = image.size.height

            // UIImage.draw(in:) 会依据 imageOrientation 将照片摆正，避免横竖颠倒。
            image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))

            let timeFontSize = max(14, w * 0.026)
            let noteFontSize = max(12, w * 0.019)
            let maxTextWidth = w * 0.86
            let x = w * 0.03
            let bottomInset = h * 0.04

            let noteText = snapshot.note.isEmpty ? "" : "备注：\(snapshot.note)"
            let noteStyle = NSMutableParagraphStyle()
            noteStyle.lineBreakMode = .byWordWrapping
            noteStyle.lineSpacing = noteFontSize * 0.15

            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: timeFontSize),
                .foregroundColor: UIColor.white
            ]
            let noteAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: noteFontSize, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: noteStyle
            ]

            var noteHeight: CGFloat = 0
            if !noteText.isEmpty {
                let rect = (noteText as NSString).boundingRect(
                    with: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: noteAttributes,
                    context: nil
                )
                noteHeight = ceil(rect.height)
            }

            let timeHeight = timeFontSize * 1.25
            let gap: CGFloat = noteHeight > 0 ? noteFontSize * 0.45 : 0
            let blockHeight = timeHeight + gap + noteHeight
            let topOfBlock = h - bottomInset - blockHeight
            let gradientTop = max(0, topOfBlock - timeFontSize * 0.6)

            // 半透明黑色渐变，保证明亮背景下文字可读。
            let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.55).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors as CFArray,
                                         locations: [0, 1]) {
                cg.saveGState()
                cg.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: gradientTop),
                                      end: CGPoint(x: 0, y: h),
                                      options: [])
                cg.restoreGState()
            }

            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: max(1, timeFontSize * 0.03)),
                         blur: max(2, timeFontSize * 0.15),
                         color: UIColor.black.withAlphaComponent(0.75).cgColor)

            let timeRect = CGRect(x: x, y: h - bottomInset - timeHeight,
                                  width: maxTextWidth, height: timeHeight)
            (snapshot.timeText as NSString).draw(in: timeRect, withAttributes: timeAttributes)

            if !noteText.isEmpty {
                let noteRect = CGRect(x: x, y: h - bottomInset - noteHeight,
                                      width: maxTextWidth, height: noteHeight)
                (noteText as NSString).draw(in: noteRect, withAttributes: noteAttributes)
            }
            cg.restoreGState()
        }
    }
}
