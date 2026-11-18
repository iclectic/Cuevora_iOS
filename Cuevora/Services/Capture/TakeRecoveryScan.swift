import AVFoundation
import Foundation

actor TakeRecoveryScan {
    static let shared = TakeRecoveryScan()

    func collect() async -> [RecoveredTake] {
        guard let folder = try? RecordingFiles.folder() else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var found: [RecoveredTake] = []
        for marker in files where marker.pathExtension == "writing" {
            let movie = marker.deletingPathExtension()
            var playable = false
            var duration = 0.0
            if FileManager.default.fileExists(atPath: movie.path) {
                let asset = AVURLAsset(url: movie)
                playable = (try? await asset.load(.isPlayable)) ?? false
                let seconds = (try? await asset.load(.duration)).map { CMTimeGetSeconds($0) } ?? 0
                duration = seconds.isFinite ? seconds : 0
            }
            found.append(TakeRecovery.decide(fileName: movie.lastPathComponent, playable: playable, duration: duration))
            try? FileManager.default.removeItem(at: marker)
        }
        return found
    }
}
