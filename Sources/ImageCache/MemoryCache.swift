import Foundation
import Etcetera
import Combine

#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

@MainActor final class MemoryCache<Key: Hashable, Value> {

    var shouldRemoveAllObjectsWhenAppEntersBackground = false

    private var items = ProtectedDictionary<Key, Value>()
    private var cancellables = Set<AnyCancellable>()

    subscript(key: Key) -> Value? {
        get { return items[key] }
        set { items[key] = newValue }
    }

    subscript(filter: (Key) -> Bool) -> [Key: Value] {
        return items.access {
            $0.filter { filter($0.key) }
        }
    }

    #if os(iOS)
    init() {
        NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.removeAll()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIScene.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if self.shouldRemoveAllObjectsWhenAppEntersBackground {
                        self.removeAll()
                    }
                }
            }
            .store(in: &cancellables)
    }
    #endif

    func removeAll() {
        items.access { $0.removeAll() }
    }

}
