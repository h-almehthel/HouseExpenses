import Foundation
import UIKit

final class AttachmentManager {
    static let shared = AttachmentManager()

    private let fileManager = FileManager.default

    private var attachmentsDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Attachments", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    func saveImage(_ image: UIImage, originalName: String? = nil) throws -> SavedAttachment {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw AttachmentError.cannotEncode
        }
        let fileName = "\(UUID().uuidString).jpg"
        try data.write(to: attachmentsDirectory.appendingPathComponent(fileName), options: .atomic)
        return SavedAttachment(fileName: originalName ?? "صورة.jpg", fileType: "image", relativePath: fileName)
    }

    func savePDF(from sourceURL: URL) throws -> SavedAttachment {
        let fileName = "\(UUID().uuidString).pdf"
        let destination = attachmentsDirectory.appendingPathComponent(fileName)
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return SavedAttachment(fileName: sourceURL.lastPathComponent, fileType: "pdf", relativePath: fileName)
    }

    func url(for relativePath: String) -> URL {
        attachmentsDirectory.appendingPathComponent(relativePath)
    }

    func delete(relativePath: String) {
        try? fileManager.removeItem(at: url(for: relativePath))
    }
}

struct SavedAttachment {
    let fileName: String
    let fileType: String
    let relativePath: String
}

enum AttachmentError: LocalizedError {
    case cannotEncode

    var errorDescription: String? {
        "تعذر تجهيز الملف المرفق."
    }
}
