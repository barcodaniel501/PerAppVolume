# AGENTS.es.md — PerAppVolume

Instrucciones para agentes de IA de programación (Claude Code, Codex, Cursor, Copilot…) que necesiten **instalar**, **compilar** o **modificar** PerAppVolume. Versión en inglés: [AGENTS.md](AGENTS.md).

PerAppVolume es una app de la barra de menú de macOS (Swift + SwiftUI, Swift Package Manager, sin proyecto de Xcode) que controla el volumen de cada app usando *process taps* de Core Audio. Requiere **macOS 14.2+**.

## Instalar para el usuario

Sigue estos pasos en orden e informa el resultado de cada uno. Si una comprobación falla, detente y avísale al usuario.

1. **Comprueba la plataforma.** `sw_vers -productVersion` debe ser 14.2 o posterior.
2. **Instala la última versión publicada** (preferido, no requiere herramientas de compilación):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/<tu-usuario>/PerAppVolume/main/scripts/install.sh | bash
   ```
   Desde un clon local puedes ejecutar `PERAPPVOLUME_REPO=<dueño>/PerAppVolume ./scripts/install.sh`.
   El script descarga el zip del release, reemplaza `/Applications/PerAppVolume.app`, quita el atributo de cuarentena y abre la app.
3. **Si todavía no hay release, compila desde el código fuente** (requiere las Command Line Tools; `xcode-select -p` debe mostrar una ruta; si no, pídele al usuario que ejecute `xcode-select --install`):
   ```bash
   make install && open /Applications/PerAppVolume.app
   ```
   La compilación universal tarda unos minutos; `ARCHS=arm64 make install` es más rápida en Apple Silicon.
4. **Verifica:**
   ```bash
   pgrep -x PerAppVolume
   ```
   ```bash
   /Applications/PerAppVolume.app/Contents/MacOS/PerAppVolume --list
   ```
   El primer comando muestra un PID si la app está abierta. El segundo lista las apps que ve Core Audio (`[playing]` / `[idle]`) y termina.
5. **Dile al usuario lo que solo él puede hacer:**
   - Hacer clic en el **ícono de controles** de la barra de menú.
   - La primera vez que mueva el control de una app, macOS pedirá **Grabación de audio del sistema**: debe hacer clic en **Permitir**. Un agente no puede ni debe conceder este permiso.
   - Si la instaló a mano (sin el script) y macOS la bloquea: **Ajustes del Sistema › Privacidad y seguridad › Abrir igualmente**.

No uses nunca `sudo`: la instalación no necesita permisos de administrador y no instala drivers.

### Desinstalar

```bash
osascript -e 'quit app "PerAppVolume"'; rm -rf /Applications/PerAppVolume.app
```

Opcional, borra los volúmenes y ajustes guardados: `defaults delete io.github.perappvolume.PerAppVolume`.

## Compilar y ejecutar

| Comando | Qué hace |
| --- | --- |
| `swift build` | Compilación de depuración, la forma más rápida de comprobar que el código compila |
| `make app` | `build/PerAppVolume.app` universal + `build/PerAppVolume-<versión>.zip` |
| `make install` | `make app` y copia a `/Applications` |
| `make run` | `make app` y la abre |
| `make icon` | Regenera `AppBundle/AppIcon.icns` a partir de `scripts/make-icon.swift` |

No hay pruebas unitarias. Para comprobar un cambio: `swift build`, luego `make install`, abre la app y ejecuta `--list`. El comportamiento del audio (taps) solo lo puede confirmar el usuario escuchando, porque necesita el permiso de Grabación de audio del sistema.

Cada compilación tiene una firma ad-hoc nueva, así que macOS puede volver a pedirle al usuario el permiso de audio tras reinstalar.

## Mapa del proyecto

```
Package.swift                      manifiesto de SwiftPM (macOS 14.2, modo de lenguaje Swift 5)
AppBundle/                         Info.plist, AppIcon.icns, en.lproj / es.lproj
scripts/build-app.sh               compila por arquitectura, lipo, arma la .app, firma ad-hoc, zip
scripts/install.sh                 instala el último release de GitHub
scripts/make-icon.swift            dibuja el ícono de la app
.github/workflows/release.yml      compilación en CI; publica un Release con tags v*
Sources/PerAppVolume/
  main.swift                       punto de entrada; maneja --list
  PerAppVolumeApp.swift            escena MenuBarExtra + AppDelegate
  MixerModel.swift                 lista de apps, volúmenes guardados, crea/elimina taps
  Audio/AppTap.swift               process tap + dispositivo agregado privado + ganancia en tiempo real
  Audio/AudioProcessScanner.swift  procesos de audio agrupados por el paquete .app más externo
  Audio/SystemVolume.swift         volumen/silencio de la salida de audio
  Audio/CoreAudioHelpers.swift     utilidades de Core Audio HAL
  Localization.swift               todos los textos de la interfaz (inglés + español)
  LaunchAtLogin.swift              envoltorio de SMAppService
  WindowManager.swift              ventanas del mezclador y de ajustes
  Views/                           vistas SwiftUI
```

## Reglas para hacer cambios

- **Bilingüe:** todo texto visible va en `Localization.swift` con su versión en inglés y en español. Nunca escribas textos fijos en las vistas.
- **Documentación sincronizada:** actualiza `README.md` (inglés, principal) y `README.es.md`, y también `AGENTS.md` y `AGENTS.es.md` cuando cambien las instrucciones.
- **Código en tiempo real:** `AppTap.render` corre en el hilo de audio. Ahí no se crean asignaciones de memoria, bloqueos, logs ni arreglos de Swift.
- **Sin drivers ni sudo:** mantén el diseño sin drivers basado en `CATapDescription` con `muteBehavior = .mutedWhenTapped`.
- **Versión:** sube `CFBundleShortVersionString` en `AppBundle/Info.plist`; los releases se crean al subir un tag `vX.Y.Z`.
