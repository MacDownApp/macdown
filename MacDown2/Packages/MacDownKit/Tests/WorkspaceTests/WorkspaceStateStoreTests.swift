import Foundation
import Testing
@testable import Workspace

@MainActor
@Suite("WorkspaceStateStore")
struct WorkspaceStateStoreTests {
    @Test func stateStoreDefaultsToSidebarVisible() {
        let suiteName = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        let store = WorkspaceStateStore(defaults: defaults)
        #expect(store.sidebarVisible == true)
    }

    @Test func stateStoreDefaultsToVisibleForNonBooleanValue() {
        let suiteName = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        defaults.set("not a bool", forKey: "sidebarVisible")

        let store = WorkspaceStateStore(defaults: defaults)
        #expect(store.sidebarVisible == true)
    }

    @Test func stateStorePersistsSidebarVisibility() {
        let suiteName = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        var store = WorkspaceStateStore(defaults: defaults)
        store.sidebarVisible = false

        let reloaded = WorkspaceStateStore(defaults: defaults)
        #expect(reloaded.sidebarVisible == false)
    }

    @Test func stateStorePersistsSectionExpansion() {
        let suiteName = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        var store = WorkspaceStateStore(defaults: defaults)
        store.sidebarSectionExpanded = ["folder": true, "outline": false]

        let reloaded = WorkspaceStateStore(defaults: defaults)
        #expect(reloaded.sidebarSectionExpanded["folder"] == true)
        #expect(reloaded.sidebarSectionExpanded["outline"] == false)
    }

    @Test func stateStoreReturnsEmptySectionsByDefault() {
        let suiteName = UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create test UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        let store = WorkspaceStateStore(defaults: defaults)
        #expect(store.sidebarSectionExpanded.isEmpty)
    }
}
