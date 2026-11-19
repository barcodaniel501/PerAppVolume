import Foundation

enum LanguageChoice: String, CaseIterable, Identifiable {
    case system, en, es
    var id: String { rawValue }
}

enum Language { case en, es }

/// In-app localization so the language can be changed live from Settings, without restarting.
@MainActor
final class Localizer: ObservableObject {
    static let shared = Localizer()

    @Published var choice: LanguageChoice {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: "language") }
    }

    private init() {
        choice = LanguageChoice(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system
    }

    var language: Language {
        switch choice {
        case .en: return .en
        case .es: return .es
        case .system: return Locale.preferredLanguages.first?.hasPrefix("es") == true ? .es : .en
        }
    }

    func t(_ key: L) -> String {
        let pair = key.text
        return language == .es ? pair.es : pair.en
    }

    func label(for choice: LanguageChoice) -> String {
        switch choice {
        case .system: return t(.languageSystem)
        case .en: return "English"
        case .es: return "Español"
        }
    }
}

/// All user-facing strings, in English and Spanish.
enum L {
    case subtitle, noApps, noAppsHint, openWindow, settings, quit
    case mute, unmute, resetApp, resetAll, playing, idle
    case settingsTitle, general, launchAtLogin, launchAtLoginHelp, launchNeedsApproval, launchMoveToApplications
    case language, languageHelp, languageSystem
    case permissions, permissionsHelp, openPrivacy
    case about, version, aboutText, tapError
    case systemVolume, systemVolumeUnavailable, apps

    var text: (en: String, es: String) {
        switch self {
        case .subtitle: return ("Volume per app", "Volumen por aplicación")
        case .noApps: return ("No apps are playing audio right now.", "Ninguna app está reproduciendo audio ahora.")
        case .noAppsHint: return ("Play something (a call, a video, a voice note) and it will show up here.",
                                  "Reproduce algo (una llamada, un video, un audio) y aparecerá aquí.")
        case .openWindow: return ("Open Window", "Abrir ventana")
        case .settings: return ("Settings…", "Ajustes…")
        case .quit: return ("Quit", "Salir")
        case .mute: return ("Mute", "Silenciar")
        case .unmute: return ("Unmute", "Activar sonido")
        case .resetApp: return ("Reset to 100%", "Restablecer a 100%")
        case .resetAll: return ("Reset all volumes", "Restablecer todos los volúmenes")
        case .playing: return ("Playing", "Reproduciendo")
        case .idle: return ("Idle", "Inactiva")
        case .settingsTitle: return ("Settings", "Ajustes")
        case .general: return ("General", "General")
        case .launchAtLogin: return ("Open at login", "Abrir al iniciar sesión")
        case .launchAtLoginHelp: return ("Start PerAppVolume automatically when you log in to your Mac.",
                                         "Inicia PerAppVolume automáticamente al encender o iniciar sesión en tu Mac.")
        case .launchNeedsApproval: return ("macOS needs your approval: open System Settings › General › Login Items.",
                                           "macOS necesita tu aprobación: abre Ajustes del Sistema › General › Ítems de inicio.")
        case .launchMoveToApplications: return ("Tip: move PerAppVolume to the Applications folder before enabling this.",
                                                "Consejo: mueve PerAppVolume a la carpeta Aplicaciones antes de activar esto.")
        case .language: return ("Language", "Idioma")
        case .languageHelp: return ("Language of the PerAppVolume interface.", "Idioma de la interfaz de PerAppVolume.")
        case .languageSystem: return ("Same as system", "Igual que el sistema")
        case .permissions: return ("Permissions", "Permisos")
        case .permissionsHelp: return ("PerAppVolume needs the “System Audio Recording” permission to change each app's volume. Audio is processed in real time and is never recorded or saved. If an app goes silent when you move its slider, check this permission.",
                                       "PerAppVolume necesita el permiso de “Grabación de audio del sistema” para cambiar el volumen de cada app. El audio se procesa en tiempo real y nunca se graba ni se guarda. Si una app queda en silencio al mover su control, revisa este permiso.")
        case .openPrivacy: return ("Open Privacy & Security", "Abrir Privacidad y seguridad")
        case .about: return ("About", "Acerca de")
        case .version: return ("Version", "Versión")
        case .aboutText: return ("Free and open source. Control the volume of each app independently, up to 200%.",
                                 "Libre y de código abierto. Controla el volumen de cada app por separado, hasta 200%.")
        case .tapError: return ("Couldn't control this app's audio:", "No se pudo controlar el audio de esta app:")
        case .systemVolume: return ("System", "Sistema")
        case .systemVolumeUnavailable: return ("This output device doesn't allow changing its volume from the Mac.",
                                               "Esta salida de audio no permite cambiar su volumen desde el Mac.")
        case .apps: return ("Open apps", "Apps abiertas")
        }
    }
}
