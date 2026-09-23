import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var config = RsyncConfig.load()
    @StateObject private var runner = RsyncRunner()
    @State private var confirmDelete = false

    var body: some View {
        VSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    pathsSection
                    OptionsPanel(config: config)
                    advancedSection
                    previewSection
                }
                .padding()
            }
            .frame(minHeight: 320)

            VStack(spacing: 0) {
                actionBar
                Divider()
                OutputView(runner: runner)
            }
            .frame(minHeight: 160)
        }
        .alert("Run with deletion enabled?", isPresented: $confirmDelete) {
            Button("Run", role: .destructive) { start(dryRun: false) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("One or more delete options are enabled. Files may be permanently removed from the destination (or source). Consider a Dry Run first.")
        }
    }

    // MARK: - Sections

    private var pathsSection: some View {
        GroupBox("Paths") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Source")
                    TextField("/path/to/source or user@host:/path", text: $config.source)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        Button("Choose…") { choosePath(into: $config.source) }
                        DropWell(text: $config.source)
                    }
                }
                GridRow {
                    Text("Destination")
                    TextField("/path/to/destination or user@host:/path", text: $config.destination)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        Button("Choose…") { choosePath(into: $config.destination) }
                        DropWell(text: $config.destination)
                    }
                }
                GridRow {
                    Color.clear.frame(width: 0, height: 0)
                    HStack {
                        Toggle("Append trailing slash to source (copy contents, not the folder itself)", isOn: $config.appendSourceSlash)
                            .toggleStyle(.checkbox)
                        Spacer()
                        Button("Swap") {
                            let s = config.source
                            config.source = config.destination
                            config.destination = s
                        }
                        .help("Swap source and destination")
                    }
                    .gridCellColumns(2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var advancedSection: some View {
        GroupBox("Advanced") {
            Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Exclude patterns")
                    VStack(alignment: .leading, spacing: 2) {
                        TextEditor(text: $config.excludes)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 70)
                            .border(Color(nsColor: .separatorColor))
                        Text("One pattern per line, e.g. node_modules, *.tmp, .git/")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .gridCellColumns(2)
                }
                GridRow {
                    Text("Remote shell (-e)")
                    TextField("ssh -p 22 -i ~/.ssh/id_ed25519", text: $config.sshCommand)
                        .textFieldStyle(.roundedBorder)
                        .gridCellColumns(2)
                }
                GridRow {
                    Text("Bandwidth limit")
                    HStack {
                        TextField("e.g. 5m or 5000 (KiB/s)", text: $config.bwLimit)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                        Text("--bwlimit").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .gridCellColumns(2)
                }
                GridRow {
                    Text("Extra arguments")
                    TextField("--max-size=1g --log-file=~/rsync.log", text: $config.extraArgs)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .gridCellColumns(2)
                }
                GridRow {
                    Text("rsync binary")
                    TextField("/usr/bin/rsync", text: $config.rsyncPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Button("Choose…") { chooseExecutable() }
                        Button("Version") { showVersion() }
                            .disabled(runner.isRunning || !FileManager.default.isExecutableFile(atPath: config.rsyncPath))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var previewSection: some View {
        GroupBox("Command") {
            HStack(alignment: .top) {
                Text(config.commandPreview())
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(config.commandPreview(), forType: .string)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Dry Run") { start(dryRun: true) }
                .disabled(runner.isRunning || !config.isRunnable)
                .help("Run rsync with -n: shows what would change without touching anything")

            Button("Run") {
                if config.usesDeletion && !config.enabled.contains("-n") {
                    confirmDelete = true
                } else {
                    start(dryRun: false)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(runner.isRunning || !config.isRunnable)

            Button("Stop") { runner.stop() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!runner.isRunning)

            Spacer()

            statusLabel

            Button("Clear Output") { runner.clear() }
                .disabled(runner.isRunning || runner.output.isEmpty)
            Button("Reset Options") { config.resetOptions() }
                .disabled(runner.isRunning)
        }
        .padding(8)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if runner.isRunning {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Running…").foregroundStyle(.secondary)
            }
        } else if let code = runner.lastExitCode {
            Label(code == 0 ? "Finished" : "Exit \(code)",
                  systemImage: code == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(code == 0 ? Color.green : Color.orange)
        } else if !config.isRunnable {
            Text(FileManager.default.isExecutableFile(atPath: config.rsyncPath)
                 ? "Enter a source and destination"
                 : "rsync binary not found")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func start(dryRun: Bool) {
        runner.run(executable: config.rsyncPath, arguments: config.arguments(dryRun: dryRun))
    }

    private func showVersion() {
        runner.run(executable: config.rsyncPath, arguments: ["--version"])
    }

    private func choosePath(into binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url.path
        }
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/usr/bin")
        if panel.runModal() == .OK, let url = panel.url {
            config.rsyncPath = url.path
        }
    }
}

/// A visible drop target: drag a file or folder from the Finder onto it to set the path.
/// (A plain text field handles drops itself and inserts the path as text, so a separate
/// well is used to replace the whole value instead.)
struct DropWell: View {
    @Binding var text: String
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.down.doc")
            Text("Drop file or folder here")
        }
        .font(.callout)
        .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 10)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isTargeted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5),
                              style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .help("Drop a file or folder here to use its path")
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
                    return false
                }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { text = url.path }
                }
                return true
            }
    }
}

#Preview {
    ContentView()
}
