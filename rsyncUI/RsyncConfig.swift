import Foundation
import Combine
import SwiftUI

// MARK: - Option catalog

struct RsyncOption: Identifiable, Hashable {
    var id: String { flag }
    let flag: String
    let title: String
    let help: String
}

struct RsyncOptionGroup: Identifiable {
    var id: String { title }
    let title: String
    let options: [RsyncOption]
}

enum RsyncOptionCatalog {
    static let groups: [RsyncOptionGroup] = [
        RsyncOptionGroup(title: "Common", options: [
            RsyncOption(flag: "-a", title: "Archive", help: "Archive mode: same as -rlptgoD (recursive, symlinks, perms, times, group, owner, devices)."),
            RsyncOption(flag: "-v", title: "Verbose", help: "Increase verbosity; lists transferred files."),
            RsyncOption(flag: "-z", title: "Compress", help: "Compress file data during transfer (useful over the network)."),
            RsyncOption(flag: "--progress", title: "Show progress", help: "Show per-file progress during transfer."),
            RsyncOption(flag: "-n", title: "Dry run", help: "Perform a trial run with no changes made."),
            RsyncOption(flag: "-h", title: "Human-readable", help: "Output numbers in a human-readable format."),
            RsyncOption(flag: "-u", title: "Update only", help: "Skip files that are newer on the receiver."),
            RsyncOption(flag: "-c", title: "Checksum", help: "Skip based on checksum, not modification time and size (slower)."),
        ]),
        RsyncOptionGroup(title: "Preserve (already included in Archive)", options: [
            RsyncOption(flag: "-r", title: "Recursive", help: "Recurse into directories."),
            RsyncOption(flag: "-l", title: "Symlinks as symlinks", help: "Copy symlinks as symlinks."),
            RsyncOption(flag: "-p", title: "Permissions", help: "Preserve permissions."),
            RsyncOption(flag: "-t", title: "Modification times", help: "Preserve modification times."),
            RsyncOption(flag: "-g", title: "Group", help: "Preserve group."),
            RsyncOption(flag: "-o", title: "Owner", help: "Preserve owner (super-user only)."),
            RsyncOption(flag: "-D", title: "Devices & specials", help: "Preserve device and special files."),
            RsyncOption(flag: "-H", title: "Hard links", help: "Preserve hard links (not part of -a)."),
            RsyncOption(flag: "-A", title: "ACLs", help: "Preserve ACLs (implies -p)."),
            RsyncOption(flag: "-X", title: "Extended attributes", help: "Preserve extended attributes (Finder tags, resource forks, etc.)."),
            RsyncOption(flag: "--numeric-ids", title: "Numeric IDs", help: "Don't map uid/gid values by user/group name."),
        ]),
        RsyncOptionGroup(title: "Transfer", options: [
            RsyncOption(flag: "-P", title: "Partial + progress", help: "Same as --partial --progress."),
            RsyncOption(flag: "--partial", title: "Keep partial files", help: "Keep partially transferred files so interrupted transfers can resume."),
            RsyncOption(flag: "-x", title: "One file system", help: "Don't cross filesystem boundaries."),
            RsyncOption(flag: "-W", title: "Whole file", help: "Copy files whole, without the delta-transfer algorithm (faster on local disks)."),
            RsyncOption(flag: "--inplace", title: "Update in place", help: "Update destination files in place instead of creating temp copies."),
            RsyncOption(flag: "-S", title: "Sparse", help: "Handle sparse files efficiently."),
            RsyncOption(flag: "-L", title: "Follow symlinks", help: "Transform symlinks into the referent file/dir."),
            RsyncOption(flag: "--size-only", title: "Size only", help: "Skip files that match in size (ignore times)."),
            RsyncOption(flag: "--ignore-existing", title: "Ignore existing", help: "Skip updating files that already exist on the receiver."),
            RsyncOption(flag: "--existing", title: "Existing only", help: "Only update files that already exist on the receiver."),
            RsyncOption(flag: "--exclude=.DS_Store", title: "Exclude .DS_Store", help: "Skip Finder metadata files."),
        ]),
        RsyncOptionGroup(title: "Deletion (use with care)", options: [
            RsyncOption(flag: "--delete", title: "Delete extraneous", help: "Delete files in the destination that don't exist in the source."),
            RsyncOption(flag: "--delete-before", title: "Delete before", help: "Receiver deletes before the transfer."),
            RsyncOption(flag: "--delete-during", title: "Delete during", help: "Receiver deletes during the transfer."),
            RsyncOption(flag: "--delete-after", title: "Delete after", help: "Receiver deletes after the transfer."),
            RsyncOption(flag: "--delete-excluded", title: "Delete excluded", help: "Also delete excluded files from the destination."),
            RsyncOption(flag: "--force", title: "Force", help: "Force deletion of directories even if not empty."),
            RsyncOption(flag: "--remove-source-files", title: "Remove source files", help: "Sender removes synchronized files (non-directories) after transfer."),
        ]),
        RsyncOptionGroup(title: "Output", options: [
            RsyncOption(flag: "--stats", title: "Statistics", help: "Print a transfer summary at the end."),
            RsyncOption(flag: "-i", title: "Itemize changes", help: "Output a change-summary for every update."),
            RsyncOption(flag: "--info=progress2", title: "Overall progress", help: "Show whole-transfer progress instead of per-file (rsync 3.1+)."),
            RsyncOption(flag: "-q", title: "Quiet", help: "Suppress non-error messages."),
        ]),
    ]

    static let allOptions: [RsyncOption] = groups.flatMap { $0.options }

    static let deleteFlags: Set<String> = [
        "--delete", "--delete-before", "--delete-during", "--delete-after",
        "--delete-excluded", "--force", "--remove-source-files",
    ]

    static let defaultEnabled: Set<String> = ["-a", "-v", "-h", "--progress"]
}

// MARK: - Config model

final class RsyncConfig: ObservableObject {
    @Published var source: String = ""
    @Published var destination: String = ""
    @Published var appendSourceSlash: Bool = true
    @Published var enabled: Set<String> = RsyncOptionCatalog.defaultEnabled
    @Published var excludes: String = ""
    @Published var sshCommand: String = ""
    @Published var bwLimit: String = ""
    @Published var extraArgs: String = ""
    @Published var rsyncPath: String = RsyncConfig.detectRsync()

    private var cancellable: AnyCancellable?

    init() {
        cancellable = objectWillChange
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.save() }
    }

    // MARK: Bindings

    func binding(for option: RsyncOption) -> Binding<Bool> {
        Binding(
            get: { self.enabled.contains(option.flag) },
            set: { on in
                if on { self.enabled.insert(option.flag) } else { self.enabled.remove(option.flag) }
            }
        )
    }

    var usesDeletion: Bool {
        !enabled.isDisjoint(with: RsyncOptionCatalog.deleteFlags)
    }

    var isRunnable: Bool {
        !source.trimmingCharacters(in: .whitespaces).isEmpty
            && !destination.trimmingCharacters(in: .whitespaces).isEmpty
            && FileManager.default.isExecutableFile(atPath: rsyncPath)
    }

    func resetOptions() {
        enabled = RsyncOptionCatalog.defaultEnabled
        excludes = ""
        sshCommand = ""
        bwLimit = ""
        extraArgs = ""
    }

    // MARK: Argument building

    var effectiveSource: String {
        var s = source.trimmingCharacters(in: .whitespaces)
        if appendSourceSlash, !s.isEmpty, !s.hasSuffix("/") { s += "/" }
        return s
    }

    var effectiveDestination: String {
        destination.trimmingCharacters(in: .whitespaces)
    }

    /// Builds the argument list (without the executable). Pass `dryRun: true` to force `-n`.
    func arguments(dryRun: Bool = false) -> [String] {
        var args: [String] = []

        // Catalog options, in catalog order for a stable command line.
        for option in RsyncOptionCatalog.allOptions where enabled.contains(option.flag) {
            args.append(option.flag)
        }
        if dryRun, !args.contains("-n") { args.append("-n") }

        for line in excludes.split(whereSeparator: \.isNewline) {
            let pattern = line.trimmingCharacters(in: .whitespaces)
            if !pattern.isEmpty { args.append("--exclude=\(pattern)") }
        }

        let ssh = sshCommand.trimmingCharacters(in: .whitespaces)
        if !ssh.isEmpty { args += ["-e", ssh] }

        let bw = bwLimit.trimmingCharacters(in: .whitespaces)
        if !bw.isEmpty { args.append("--bwlimit=\(bw)") }

        args += RsyncConfig.tokenize(extraArgs)

        args.append(effectiveSource)
        args.append(effectiveDestination)
        return args
    }

    func commandPreview(dryRun: Bool = false) -> String {
        ([rsyncPath] + arguments(dryRun: dryRun)).map(RsyncConfig.shellQuote).joined(separator: " ")
    }

    // MARK: Helpers

    static func shellQuote(_ s: String) -> String {
        if s.isEmpty { return "''" }
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./:@%+=,~"))
        if s.unicodeScalars.allSatisfy({ safe.contains($0) }) { return s }
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Minimal shell-like tokenizer: splits on whitespace, honours single/double quotes and backslash escapes.
    static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inToken = false
        var quote: Character? = nil
        var escape = false

        for ch in input {
            if escape {
                current.append(ch); escape = false; inToken = true; continue
            }
            if ch == "\\" && quote != "'" { escape = true; continue }
            if let q = quote {
                if ch == q { quote = nil } else { current.append(ch) }
                continue
            }
            if ch == "\"" || ch == "'" { quote = ch; inToken = true; continue }
            if ch.isWhitespace {
                if inToken { tokens.append(current); current = ""; inToken = false }
                continue
            }
            current.append(ch); inToken = true
        }
        if inToken { tokens.append(current) }
        return tokens
    }

    static func detectRsync() -> String {
        let candidates = ["/opt/homebrew/bin/rsync", "/usr/local/bin/rsync", "/usr/bin/rsync"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/usr/bin/rsync"
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var source: String
        var destination: String
        var appendSourceSlash: Bool
        var enabled: [String]
        var excludes: String
        var sshCommand: String
        var bwLimit: String
        var extraArgs: String
        var rsyncPath: String
    }

    private static let defaultsKey = "rsyncUI.config"

    func save() {
        let snap = Snapshot(
            source: source, destination: destination, appendSourceSlash: appendSourceSlash,
            enabled: Array(enabled).sorted(), excludes: excludes, sshCommand: sshCommand,
            bwLimit: bwLimit, extraArgs: extraArgs, rsyncPath: rsyncPath
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: RsyncConfig.defaultsKey)
        }
    }

    static func load() -> RsyncConfig {
        let config = RsyncConfig()
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return config }
        config.source = snap.source
        config.destination = snap.destination
        config.appendSourceSlash = snap.appendSourceSlash
        config.enabled = Set(snap.enabled)
        config.excludes = snap.excludes
        config.sshCommand = snap.sshCommand
        config.bwLimit = snap.bwLimit
        config.extraArgs = snap.extraArgs
        if FileManager.default.isExecutableFile(atPath: snap.rsyncPath) {
            config.rsyncPath = snap.rsyncPath
        }
        return config
    }
}
