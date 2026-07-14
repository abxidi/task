import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import TaskPersistence

struct BackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImport: BackupEnvelope?
    @State private var status = ""
    @State private var showConfirmReplace = false

    var body: some View {
        Form {
            Section("JSON 备份") {
                Text("导出不包含 API Key 与 AI 配置。")
                    .foregroundStyle(.secondary)
                Button("导出备份") { export() }
                Button("导入备份…") { isImporting = true }
            }
            if !status.isEmpty {
                Section {
                    Text(status)
                }
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "task-backup"
        ) { result in
            switch result {
            case .success:
                status = "导出完成"
            case .failure(let error):
                status = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importFile(url)
            case .failure(let error):
                status = error.localizedDescription
            }
        }
        .confirmationDialog("用备份替换当前数据？", isPresented: $showConfirmReplace) {
            Button("替换", role: .destructive) {
                applyPendingImport()
            }
            Button("取消", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            if let pendingImport {
                Text("将导入 \(pendingImport.tasks.count) 个任务、\(pendingImport.projects.count) 个项目。")
            }
        }
    }

    private func export() {
        do {
            let data = try BackupService(context: modelContext).exportSnapshot(now: .now)
            exportDocument = BackupDocument(data: data)
            isExporting = true
        } catch {
            status = error.localizedDescription
        }
    }

    private func importFile(_ url: URL) {
        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pendingImport = try BackupService(context: modelContext).validateImport(data)
            showConfirmReplace = true
            status = "校验通过，等待确认"
        } catch {
            status = "导入校验失败：\(error.localizedDescription)"
            pendingImport = nil
        }
    }

    private func applyPendingImport() {
        guard let pendingImport else { return }
        do {
            try BackupService(context: modelContext).applyImport(pendingImport)
            status = "导入完成"
        } catch {
            status = "导入失败，当前数据未改动：\(error.localizedDescription)"
        }
        self.pendingImport = nil
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
