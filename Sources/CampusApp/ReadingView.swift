import SwiftUI
import CampusCore

struct ReadingView: View {
    @Environment(AppStore.self) private var store
    @State private var status: ReadingStatus?
    @State private var category: String?
    @State private var query = ""
    @State private var editor: ReadingBook?
    @State private var managingCategories = false
    private var filtered: [ReadingBook] { ReadingShelf.filter(store.data.books, status: status, category: category, query: query) }
    private var categories: [String] { ReadingShelf.categories(store.data.books) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(eyebrow: "A SHELF OF POSSIBILITIES", title: "阅读书单", subtitle: "把想读的故事收藏起来，也为读过的世界留一席位置。")
            HStack(spacing: 16) {
                Stat(title: "我的藏书", value: "\(store.data.books.count)", suffix: "本")
                Stat(title: "计划阅读", value: "\(store.data.books.filter { $0.status == .planned }.count)", suffix: "本")
                Stat(title: "已经读完", value: "\(store.data.books.filter { $0.status == .finished }.count)", suffix: "本")
            }
            HStack(spacing: 12) {
                Picker("阅读状态", selection: $status) {
                    Text("全部书籍").tag(nil as ReadingStatus?)
                    ForEach(ReadingStatus.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }.pickerStyle(.segmented).frame(maxWidth: 360).accessibilityIdentifier("reading-status")
                Spacer()
                Button("管理分类", systemImage: "folder") { managingCategories = true }
                Button("添加书籍", systemImage: "plus") { editor = ReadingBook() }.buttonStyle(.borderedProminent).accessibilityIdentifier("add-book")
            }
            HStack {
                Picker("分类", selection: $category) {
                    Text("全部分类").tag(nil as String?)
                    Text("未分类").tag(Optional(""))
                    ForEach(categories, id: \.self) { Text($0).tag(Optional($0)) }
                }.frame(maxWidth: 260).accessibilityIdentifier("reading-category")
                Spacer()
                TextField("搜索书名或作者", text: $query).textFieldStyle(.roundedBorder).frame(width: 230).accessibilityIdentifier("reading-search")
                Text("\(filtered.count) 本").font(.caption).foregroundStyle(.quiet)
            }
            if store.data.books.isEmpty {
                EmptyCard(icon: "books.vertical", title: "你的私人书架", detail: "添加计划阅读或已经读完的书，自定义分类。\n封面可以逐本从本机选择，也可以稍后补上。")
            } else if filtered.isEmpty {
                EmptyCard(icon: "magnifyingglass", title: "没有符合筛选的书", detail: "试试其他状态、分类或关键词。")
                Button("清除筛选") { status = nil; category = nil; query = "" }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 205), spacing: 22, alignment: .top)], alignment: .leading, spacing: 24) {
                    ForEach(filtered) { book in bookCard(book) }
                }
            }
        }
        .onChange(of: categories) { _, names in if let category, !category.isEmpty && !names.contains(category) { self.category = nil } }
        .sheet(item: $editor) { book in
            EditorSheet(title: "书籍与阅读记录", key: store.data.books.contains(where: { $0.id == book.id }) ? "book-\(book.id)" : "book-new", initial: book) { value in
                BookFields(book: value, categories: categories)
            } save: { value, state in
                var value = value; value.normalize(); try value.validate()
                if let i = state.books.firstIndex(where: { $0.id == value.id }) { state.books[i] = value }
                else { state.books.append(value) }
                // Show a newly added/recategorized book immediately even with previous filters.
                status = nil; category = nil; query = ""
            }
        }
        .sheet(isPresented: $managingCategories) { BookCategoriesSheet() }
    }

    private func bookCard(_ book: ReadingBook) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { editor = book } label: {
                BookCoverView(book: book).frame(height: 222).frame(maxWidth: .infinity)
            }.buttonStyle(.plain).help("编辑书籍或更换封面").accessibilityLabel("编辑 \(book.title)").accessibilityIdentifier("book-\(book.id)")
            Text(book.title).font(.headline).lineLimit(2).frame(height: 38, alignment: .topLeading).help(book.title)
            Text(book.author.isEmpty ? "作者未填写" : book.author).font(.caption).foregroundStyle(.quiet).lineLimit(1)
            HStack {
                Text(book.categoryLabel).font(.caption2).lineLimit(1).padding(.horizontal, 7).padding(.vertical, 4).background(.primary.opacity(0.06), in: Capsule())
                Spacer(minLength: 2)
                Menu {
                    Button("编辑书籍／上传封面") { editor = book }
                    Button(book.status == .planned ? "标记为已经读完" : "移回计划阅读") {
                        store.act { state in
                            if let i = state.books.firstIndex(where: { $0.id == book.id }) {
                                state.books[i].setStatus(book.status == .planned ? .finished : .planned, today: Day.today(zone: state.semester?.timeZone ?? "Asia/Shanghai"))
                            }
                        }
                    }
                    Divider()
                    Button("移到回收站（含封面）", role: .destructive) {
                        store.archive(book, kind: "book", name: book.title) { state in
                            state.books.removeAll { $0.id == book.id }; state.drafts.removeValue(forKey: "book-\(book.id)")
                        }
                    }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22)
            }
            Label(book.status.rawValue, systemImage: book.status == .finished ? "checkmark.circle.fill" : "bookmark")
                .font(.caption).foregroundStyle(book.status == .finished ? Color.mint : Color.secondary)
        }.glass(14)
    }
}

private struct BookFields: View {
    @Environment(AppStore.self) private var store
    @Binding var book: ReadingBook
    let categories: [String]
    @State private var coverError: String?
    @State private var choosing = false
    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            BookCoverView(book: book).frame(width: 120, height: 170)
            VStack(alignment: .leading, spacing: 12) {
                Text("书籍封面").font(.headline)
                Button(book.cover == nil ? "上传封面图片" : "更换封面图片", systemImage: "photo") {
                    choosing = true
                    Task { @MainActor in
                        defer { choosing = false }
                        guard let url = await FilePanels.open(extensions: ["png", "jpg", "jpeg", "heic", "heif", "webp"]) else { return }
                        do { let data = try BookCover.importImage(at: url); book.cover = data; coverError = nil }
                        catch { coverError = error.localizedDescription }
                    }
                }.disabled(choosing).accessibilityIdentifier("book-cover-upload")
                if book.cover != nil { Button("移除封面", role: .destructive) { book.cover = nil; coverError = nil } }
                Text("逐本选择本机图片，支持 PNG、JPEG、HEIC、WebP（≤30 MB）。封面将压缩保存到本机，并随备份一起导出。").font(.caption).foregroundStyle(.quiet).fixedSize(horizontal: false, vertical: true)
                if let coverError { Text(coverError).font(.caption).foregroundStyle(.orange) }
            }
        }
        Field(label: "书名", value: $book.title)
        Field(label: "作者（选填）", value: $book.author)
        HStack(alignment: .bottom) {
            Field(label: "书籍分类（可自定义）", value: $book.category, prompt: "例如：文学、历史、专业学习")
            if !categories.isEmpty { Menu("已有分类") { ForEach(categories, id: \.self) { name in Button(name) { book.category = name } }; Button("未分类") { book.category = "" } } }
        }
        Picker("阅读状态", selection: Binding(get: { book.status }, set: { book.setStatus($0, today: Day.today(zone: store.data.semester?.timeZone ?? "Asia/Shanghai")) })) {
            ForEach(ReadingStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).accessibilityIdentifier("book-status")
        if book.status == .finished { DateField(title: "读完日期（选填）", value: $book.finishedOn) }
        VStack(alignment: .leading, spacing: 8) {
            Text(book.status == .planned ? "想读的理由／阅读计划（选填）" : "阅读感受／摘记（选填）").font(.caption).foregroundStyle(.quiet)
            TextEditor(text: $book.notes).font(.body).frame(minHeight: 85).overlay(RoundedRectangle(cornerRadius: 5).stroke(.secondary.opacity(0.2)))
        }
    }
}

struct BookCoverView: View {
    let book: ReadingBook
    @State private var image: NSImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.05))
            if let image { Image(nsImage: image).resizable().scaledToFit().padding(3) }
            else {
                RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [.indigo.opacity(0.65), .cyan.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: 14) {
                    Image(systemName: "book.closed").font(.system(size: 26, weight: .light))
                    Text(book.title.isEmpty ? "等待一本好书" : book.title).font(.headline).multilineTextAlignment(.center).lineLimit(4)
                    Text("待添加封面").font(.caption2)
                }.foregroundStyle(.white).padding(14)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 8)).shadow(color: .black.opacity(0.12), radius: 5, y: 4)
            .task(id: book.cover) { image = book.cover.flatMap(NSImage.init(data:)) }
    }
}

private struct BookCategoriesSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var source: String?
    @State private var target = ""
    @State private var error: String?
    private var categories: [String] { ReadingShelf.categories(store.data.books) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("管理书籍分类").font(.title2); Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.cancelAction) }
            Text("添加或编辑书籍时可填写新分类。重命名为已有分类会合并；留空则将该分类下的书移到“未分类”，不会删除书籍。").font(.callout).foregroundStyle(.quiet)
            if categories.isEmpty { Text("还没有自定义分类。").foregroundStyle(.quiet) }
            else {
                Picker("选择分类", selection: $source) {
                    Text("请选择").tag(nil as String?)
                    ForEach(categories, id: \.self) { name in Text("\(name)（\(store.data.books.filter { $0.category == name }.count)）").tag(Optional(name)) }
                }
                Field(label: "新的分类名称", value: $target, prompt: "留空可移到未分类")
                if let source { Text("将影响 \(store.data.books.filter { $0.category == source }.count) 本书。").font(.caption).foregroundStyle(.quiet) }
                Button("应用分类变更") {
                    guard let source else { return }
                    do { try store.commit { try $0.renameBookCategory(source, to: target) }; self.source = nil; target = ""; error = nil }
                    catch { self.error = error.localizedDescription }
                }.disabled(source == nil).buttonStyle(.borderedProminent)
            }
            if let error { Text(error).foregroundStyle(.orange) }
        }.padding(28).frame(width: 500)
            .onChange(of: source) { _, name in target = name ?? "" }
    }
}
