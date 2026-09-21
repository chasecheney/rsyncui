import Foundation

@MainActor
final class RsyncRunner: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    @Published var lastExitCode: Int32? = nil

    private var process: Process?
    private let maxOutputLength = 2_000_000

    func run(executable: String, arguments: [String]) {
        guard !isRunning else { return }
        output = ""
        lastExitCode = nil

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        env["PATH"] = (extraPaths + [env["PATH"] ?? ""]).joined(separator: ":")
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        proc.standardInput = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.append(text) }
        }

        proc.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            let rest = pipe.fileHandleForReading.readDataToEndOfFile()
            let tail = String(decoding: rest, as: UTF8.self)
            let status = finished.terminationStatus
            let signalled = finished.terminationReason == .uncaughtSignal
            Task { @MainActor in
                guard let self else { return }
                if !tail.isEmpty { self.append(tail) }
                self.isRunning = false
                self.lastExitCode = status
                self.process = nil
                if signalled {
                    self.append("\n[rsync stopped]\n")
                } else {
                    self.append("\n[rsync exited with status \(status): \(RsyncRunner.describe(status))]\n")
                }
            }
        }

        let preview = ([executable] + arguments).map(RsyncConfig.shellQuote).joined(separator: " ")
        append("$ \(preview)\n\n")

        do {
            try proc.run()
            process = proc
            isRunning = true
        } catch {
            append("Failed to launch \(executable): \(error.localizedDescription)\n")
        }
    }

    func stop() {
        process?.terminate()
    }

    func clear() {
        output = ""
        lastExitCode = nil
    }

    private func append(_ text: String) {
        // rsync uses carriage returns for progress lines; show them as separate lines.
        output += text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if output.count > maxOutputLength {
            output = "…(earlier output trimmed)…\n" + output.suffix(maxOutputLength / 2)
        }
    }

    static func describe(_ code: Int32) -> String {
        switch code {
        case 0: return "success"
        case 1: return "syntax or usage error"
        case 2: return "protocol incompatibility"
        case 3: return "errors selecting input/output files or dirs"
        case 5: return "error starting client-server protocol"
        case 10: return "socket I/O error"
        case 11: return "file I/O error"
        case 12: return "error in rsync protocol data stream"
        case 13: return "errors with program diagnostics"
        case 20: return "received SIGUSR1 or SIGINT"
        case 22: return "error allocating core memory buffers"
        case 23: return "partial transfer due to error"
        case 24: return "partial transfer due to vanished source files"
        case 25: return "the --max-delete limit stopped deletions"
        case 30: return "timeout in data send/receive"
        case 35: return "timeout waiting for daemon connection"
        case 255: return "ssh connection failed"
        default: return "see rsync(1) for exit codes"
        }
    }
}
