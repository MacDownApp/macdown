import Foundation
import CoreServices

/// Reports changes below a folder using FSEvents. No polling, no timers: when
/// nothing changes, it uses no CPU. Events are delivered in batches after a
/// short delay (`latency`), so a burst of saves causes one callback.
final class DirectoryWatcher {
    private var stream: FSEventStreamRef?
    private let handler: ([URL]) -> Void
    private let queue: DispatchQueue

    /// - Parameters:
    ///   - root: The folder to watch, including everything below it.
    ///   - latency: Seconds to wait and merge events.
    ///   - queue: Where `handler` runs.
    ///   - handler: Called with the changed paths.
    init?(root: URL, latency: TimeInterval = 0.2, queue: DispatchQueue = .main, handler: @escaping ([URL]) -> Void) {
        self.handler = handler
        self.queue = queue

        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            let array = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            let urls = array.prefix(count).map { URL(fileURLWithPath: $0) }
            watcher.handler(Array(urls))
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
                           | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, [root.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags) else { return nil }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
            return nil
        }
    }

    /// Stops watching. Also called on deinit.
    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
