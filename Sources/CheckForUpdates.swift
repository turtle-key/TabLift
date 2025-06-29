import Combine
import Defaults
import Sparkle
import SwiftUI

final class UpdaterViewModel: ObservableObject {
    static let shared = UpdaterViewModel()

    @Published var canCheckForUpdates = false

    @Published var automaticallyChecksForUpdates = false {
        didSet {
            controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    @Published var updateCheckInterval: TimeInterval = 604_800 {
        didSet {
            controller.updater.updateCheckInterval = updateCheckInterval
        }
    }

    private let controller = AutoUpdateManager.shared.controller
    private var subscriptions = Set<AnyCancellable>()

    init() {
        controller.updater
            .publisher(for: \.canCheckForUpdates)
            .sink { value in
                self.canCheckForUpdates = value
            }
            .store(in: &subscriptions)

        controller.updater
            .publisher(for: \.automaticallyChecksForUpdates)
            .sink { value in
                guard value != self.automaticallyChecksForUpdates else {
                    return
                }
                self.automaticallyChecksForUpdates = value
            }
            .store(in: &subscriptions)

        controller.updater
            .publisher(for: \.updateCheckInterval)
            .sink { value in
                guard value != self.updateCheckInterval else {
                    return
                }
                self.updateCheckInterval = value
            }
            .store(in: &subscriptions)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject var updaterViewModel = UpdaterViewModel.shared

    var body: some View {
        Text("Version: (TabLift.appVersion)")
            .foregroundColor(.secondary)

        Toggle(isOn: $updaterViewModel.automaticallyChecksForUpdates.animation()) {
            Text("Check for updates automatically")
        }

        if updaterViewModel.automaticallyChecksForUpdates {
            Picker("Update check interval", selection: $updaterViewModel.updateCheckInterval) {
                Text("Daily").tag(TimeInterval(86_400))
                Text("Weekly").tag(TimeInterval(604_800))
                Text("Monthly").tag(TimeInterval(2_629_800))
            }
            .modifier(PickerViewModifier())
        }


        Button("Check for Updates…", action: updaterViewModel.checkForUpdates)
            .disabled(!updaterViewModel.canCheckForUpdates)
    }
}
