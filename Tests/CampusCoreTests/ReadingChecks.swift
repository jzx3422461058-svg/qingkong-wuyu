import Foundation
import CampusCore
import AppKit

@MainActor func readingChecks() {
    Check.run("Reading: old workspaces decode with an empty shelf") {
        let old = try JSONDecoder().decode(Workspace.self, from: Data("{}".utf8))
        try Check.equal(old.books, [])
        try old.validate()
    }
    Check.run("Reading: status transition, optional date and title validation") {
        var book = ReadingBook()
        try Check.rejects { try book.validate() }
        book.title = "  阅读一本书 \n"; book.category = " 文学 "; book.normalize()
        try Check.equal(book.title, "阅读一本书"); try Check.equal(book.category, "文学")
        book.setStatus(.finished, today: "2026-10-29"); try book.validate()
        try Check.equal(book.finishedOn, "2026-10-29")
        book.setStatus(.planned, today: "2026-10-29"); try Check.equal(book.finishedOn, "")
        book.finishedOn = "2026-02-30"; try Check.rejects { try book.validate() }
    }
    Check.run("Reading: combined status, category, author and title filters") {
        var a = ReadingBook(); a.title = "资本论"; a.author = "马克思"; a.category = "理论"
        var b = ReadingBook(); b.title = "阅读笔记"; b.status = .finished
        try Check.equal(ReadingShelf.filter([a,b], status: .planned, category: "理论", query: "马克思"), [a])
        try Check.equal(ReadingShelf.filter([a,b], status: .finished, category: "理论", query: ""), [])
        try Check.equal(ReadingShelf.filter([a,b], status: nil, category: "", query: "笔记"), [b])
        try Check.equal(ReadingShelf.categories([a,a,b]), ["理论"])
    }
    Check.run("Reading: category rename merge and removal preserve books and drafts") {
        var a = ReadingBook(); a.title = "甲"; a.category = "文学"
        var b = ReadingBook(); b.title = "乙"; b.category = "小说"
        var state = Workspace(); state.books = [a,b]; state.drafts["book-new"] = try JSONEncoder().encode(a)
        try state.renameBookCategory("文学", to: "小说")
        try Check.equal(ReadingShelf.categories(state.books), ["小说"])
        try Check.equal(try JSONDecoder().decode(ReadingBook.self, from: state.drafts["book-new"]!).category, "小说")
        try state.renameBookCategory("小说", to: "")
        try Check.equal(state.books.map(\.id), [a.id,b.id]); try Check.equal(ReadingShelf.categories(state.books), [])
    }
    Check.run("Reading: imported cover survives source deletion, restart, backup and trash restore") {
        try Check.temporary { root in
            let disk = try DiskStore<Workspace>(directory: root)
            let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 80, pixelsHigh: 120, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            let file = root.appendingPathComponent("cover.png")
            try image.representation(using: .png, properties: [:])!.write(to: file)
            var book = ReadingBook(); book.title = "封面测试"; book.cover = try BookCover.importImage(at: file)
            try FileManager.default.removeItem(at: file)
            var state = Workspace(); state.books = [book]; try disk.save(state)
            let reopened = try DiskStore<Workspace>(directory: root).load()!
            try Check.equal(reopened.books.first?.cover, book.cover)
            let bytes = try disk.encode(state)
            let trash = TrashEntry(kind: "book", name: book.title, payload: try JSONEncoder().encode(book))
            state.books = []; state.trash = [trash]; try disk.save(state)
            try state.restoreTrash(trash.id); try Check.equal(state.books, [book]); try Check.equal(state.trash, [])
            let restored = try disk.restore(bytes); try Check.equal(restored.books, [book])
        }
    }
    Check.run("Reading: bad image and duplicate identity fail without changing saved data") {
        try Check.temporary { root in
            let disk = try DiskStore<Workspace>(directory: root)
            var book = ReadingBook(); book.title = "原书"; var state = Workspace(); state.books = [book]; try disk.save(state)
            let file = root.appendingPathComponent("bad.png"); try Data("not an image".utf8).write(to: file)
            try Check.rejects { _ = try BookCover.importImage(at: file) }
            state.books[0].cover = Data("broken".utf8); try Check.rejects { try disk.save(state) }
            try Check.equal(try disk.load()?.books, [book])
            state.books = [book,book]; try Check.rejects { try disk.save(state) }
        }
    }
}
