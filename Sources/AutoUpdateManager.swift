import Defaults
import Foundation
import Sparkle
import Version

class AutoUpdateManager: NSObject {
    static let shared = AutoUpdateManager()

    private var _controller: SPUStandardUpdaterController!
    var controller: SPUStandardUpdaterController {
        _controller
    }

    override init() {
        super.init()
        _controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }
}

extension AutoUpdateManager: SPUUpdaterDelegate {
    func versionComparator(for _: SPUUpdater) -> SUVersionComparison? {
        SemanticVersioningComparator()
    }
}

class SemanticVersioningComparator: SUVersionComparison {
    func compareVersion(_ versionA: String, toVersion versionB: String) -> ComparisonResult {
        guard let a = try? Version(versionA) else {
            return .orderedAscending
        }
        guard let b = try? Version(versionB) else {
            return .orderedDescending
        }
        if a < b {
            return .orderedAscending
        }
        if a > b {
            return .orderedDescending
        }
        return .orderedSame
    }
}
