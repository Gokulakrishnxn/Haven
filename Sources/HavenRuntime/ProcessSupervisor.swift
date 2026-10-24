import Foundation

public struct ProcessExit: Equatable, Sendable {
    public var code: Int32?
    public var signal: Int32?
    public var cancelled: Bool
    public var timedOut: Bool

    public var succeeded: Bool { code == 0 && !cancelled && !timedOut }
}

public struct SpawnError: Error, CustomStringConvertible {
    public let errnoValue: Int32
    public var description: String { "Could not start process: \(String(cString: strerror(errnoValue)))" }
}

/// A running child in its own process group, so cancelling stops tools it started too.
public final class SupervisedProcess: @unchecked Sendable {
    public let pid: pid_t
    private let lock = NSLock()
    private var finished = false
    private var cancelled = false
    private var timedOut = false

    fileprivate init(pid: pid_t) { self.pid = pid }

    var wasCancelled: Bool { lock.withLock { cancelled } }
    var didTimeOut: Bool { lock.withLock { timedOut } }
    fileprivate func markFinished() { lock.withLock { finished = true } }

    /// SIGTERM to the whole group, SIGKILL if it is still alive after the grace period.
    public func terminate(grace: TimeInterval = 3) {
        stop(timedOut: false, grace: grace)
    }

    fileprivate func stop(timedOut: Bool, grace: TimeInterval) {
        let proceed: Bool = lock.withLock {
            if finished { return false }
            if timedOut { self.timedOut = true } else { cancelled = true }
            return true
        }
        guard proceed else { return }
        killpg(pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + grace) { [self] in
            let alive = lock.withLock { !finished }
            if alive { killpg(pid, SIGKILL) }
        }
    }
}

public enum ProcessSupervisor {
    /// Starts `command` (argv, first element is the executable path) and reports output and exit.
    public static func launch(
        command: [String],
        workingDirectory: URL? = nil,
        timeout: TimeInterval? = nil,
        onOutput: @escaping @Sendable (Data) -> Void,
        onExit: @escaping @Sendable (ProcessExit) -> Void
    ) throws -> SupervisedProcess {
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { throw SpawnError(errnoValue: errno) }
        let (readFD, writeFD) = (fds[0], fds[1])

        var actions: posix_spawn_file_actions_t? = nil
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, writeFD, 1)
        posix_spawn_file_actions_adddup2(&actions, writeFD, 2)
        posix_spawn_file_actions_addclose(&actions, readFD)
        posix_spawn_file_actions_addclose(&actions, writeFD)
        if let dir = workingDirectory { posix_spawn_file_actions_addchdir_np(&actions, dir.path) }

        var attr: posix_spawnattr_t? = nil
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        // New process group led by the child, with default signal handling and an empty mask
        // so SIGTERM is never inherited as blocked or ignored.
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))
        posix_spawnattr_setpgroup(&attr, 0)
        var noSignals = sigset_t()
        sigemptyset(&noSignals)
        posix_spawnattr_setsigmask(&attr, &noSignals)
        var allSignals = sigset_t()
        sigfillset(&allSignals)
        posix_spawnattr_setsigdefault(&attr, &allSignals)

        let argv: [UnsafeMutablePointer<CChar>?] = command.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }

        var pid: pid_t = 0
        let rc = posix_spawn(&pid, command[0], &actions, &attr, argv, environ)
        close(writeFD)
        guard rc == 0 else {
            close(readFD)
            throw SpawnError(errnoValue: rc)
        }

        let process = SupervisedProcess(pid: pid)
        if let timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { process.stop(timedOut: true, grace: 3) }
        }

        // One thread per task: drain output, then reap the child.
        Thread.detachNewThread {
            var buffer = [UInt8](repeating: 0, count: 8192)
            while true {
                let n = read(readFD, &buffer, buffer.count)
                if n > 0 { onOutput(Data(buffer[0..<n])) } else if n == 0 || errno != EINTR { break }
            }
            close(readFD)
            var status: Int32 = 0
            while waitpid(pid, &status, 0) < 0 && errno == EINTR {}
            process.markFinished()
            let signaled = (status & 0x7f) != 0
            onExit(ProcessExit(code: signaled ? nil : (status >> 8) & 0xff,
                               signal: signaled ? status & 0x7f : nil,
                               cancelled: process.wasCancelled,
                               timedOut: process.didTimeOut))
        }
        return process
    }
}
