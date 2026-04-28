import Foundation
import ZIPFoundation

enum EPUBTestFactory {

    static func makeMinimalEPUB(
        title: String = "Test Book",
        author: String? = "Test Author",
        includeCover: Bool = false,
        chapterHeadHTML: String = "",
        chapterBodyHTML: String = "<p>hi</p>"
    ) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).epub")

        guard let archive = Archive(url: tmp, accessMode: .create) else {
            throw NSError(domain: "epub-factory", code: 1)
        }

        // mimetype (stored, uncompressed, as required by EPUB spec)
        let mimetype = Data("application/epub+zip".utf8)
        try archive.addEntry(
            with: "mimetype",
            type: .file,
            uncompressedSize: Int64(mimetype.count),
            compressionMethod: .none
        ) { pos, size in
            mimetype.subdata(in: Int(pos)..<Int(pos) + size)
        }

        let container = """
        <?xml version="1.0"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try addText(to: archive, path: "META-INF/container.xml", text: container)

        let authorXML = author.map { "<dc:creator>\($0)</dc:creator>" } ?? ""
        let coverItem = includeCover
            ? #"<item id="cover" href="cover.png" media-type="image/png" properties="cover-image"/>"#
            : ""

        let opf = """
        <?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>\(title)</dc:title>
            \(authorXML)
          </metadata>
          <manifest>
            <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
            \(coverItem)
          </manifest>
          <spine><itemref idref="chap1"/></spine>
        </package>
        """
        try addText(to: archive, path: "OEBPS/content.opf", text: opf)
        try addText(
            to: archive,
            path: "OEBPS/chap1.xhtml",
            text: "<html><head>\(chapterHeadHTML)</head><body>\(chapterBodyHTML)</body></html>"
        )

        if includeCover {
            let png = tinyPNG()
            try archive.addEntry(
                with: "OEBPS/cover.png",
                type: .file,
                uncompressedSize: Int64(png.count),
                compressionMethod: .none
            ) { pos, size in
                png.subdata(in: Int(pos)..<Int(pos) + size)
            }
        }

        return tmp
    }

    private static func addText(to archive: Archive, path: String, text: String) throws {
        let data = Data(text.utf8)
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { pos, size in
            data.subdata(in: Int(pos)..<Int(pos) + size)
        }
    }

    private static func tinyPNG() -> Data {
        let bytes: [UInt8] = [
            0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,
            0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52,
            0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x01,
            0x08,0x06,0x00,0x00,0x00,0x1F,0x15,0xC4,
            0x89,0x00,0x00,0x00,0x0D,0x49,0x44,0x41,
            0x54,0x78,0x9C,0x62,0x00,0x01,0x00,0x00,
            0x05,0x00,0x01,0x0D,0x0A,0x2D,0xB4,0x00,
            0x00,0x00,0x00,0x49,0x45,0x4E,0x44,0xAE,
            0x42,0x60,0x82
        ]
        return Data(bytes)
    }
}
