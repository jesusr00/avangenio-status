import SwiftUI
import AvangenioStatusKit

/// Arranca el modelo al terminar el launch (aunque el panel no se haya abierto),
/// para que el polling corra en segundo plano desde el inicio.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }
}

@main
struct AvangenioStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            StatusPanelView(model: appDelegate.model)
        } label: {
            StatusIcon(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)

        Window("Ajustes de Avangenio Status", id: "settings") {
            SettingsView(model: appDelegate.model)
        }
        .windowResizability(.contentSize)
    }
}
