import SwiftUI

/// Checkbox grid for the common rsync options, grouped by purpose.
struct OptionsPanel: View {
    @ObservedObject var config: RsyncConfig

    private let columns = [GridItem(.adaptive(minimum: 250), alignment: .leading)]

    var body: some View {
        ForEach(RsyncOptionCatalog.groups) { group in
            GroupBox(group.title) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(group.options) { option in
                        Toggle(isOn: config.binding(for: option)) {
                            HStack(spacing: 6) {
                                Text(option.title)
                                Text(option.flag)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .help(option.help)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Scrolling, auto-following view of the rsync output.
struct OutputView: View {
    @ObservedObject var runner: RsyncRunner

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(runner.output.isEmpty ? "Output will appear here." : runner.output)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(runner.output.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    Color.clear.frame(height: 1).id("bottom")
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: runner.output) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
