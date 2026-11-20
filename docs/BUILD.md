# Build Guide: OpenIPTV auf macOS, iOS und Android (TV) kompilieren

Diese Anleitung beschreibt alles, um die App **lokal auf deinem Mac** zu bauen —
von den Voraussetzungen bis zur fertigen `.app`/`.dmg`, `.apk` und `.ipa`.

> Backend-Container laufen auf dem **Unraid-Server** → siehe
> [docs/INSTALL.md](INSTALL.md). Diese Datei hier ist nur das **Kompilieren**.

Die App ist eine einzige Flutter-Codebase. Du brauchst sie also nur **einmal**
herunterzuladen und baust daraus alle drei Plattformen.

```text
dein Mac                          Ausgabe
┌──────────────────────────┐   ┌─────────────────────────────────────┐
│ flutter build macos      │──▶│ OpenIPTV-macOS.dmg / open_iptv.app  │
│ flutter build apk        │──▶│ app-release.apk (Android TV)        │
│ flutter build ipa        │──▶│ OpenIPTV.ipa (iPhone/iPad)          │
└──────────────────────────┘   └─────────────────────────────────────┘
```

---

## 1. Einmalig: Entwicklungsumgebung auf dem Mac

### 1.1 Xcode (für macOS- und iOS-Builds)

1. **Xcode** aus dem Mac App Store installieren (kostenlos, einige GB).
2. Danach im Terminal:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
xcodebuild -version
```

3. Für iOS-Simulatoren/Signing zusätzlich die iOS-Platform-Komponente in
   Xcode öffnen (Settings → Platforms), falls nicht schon durch
   `-runFirstLaunch` geschehen.
4. **CocoaPods** (wird von Flutter für iOS/macOS benutzt):

```bash
sudo gem install cocoapods        # oder: brew install cocoapods
```

### 1.2 Android Studio + Android SDK (für Android/Android TV)

1. [Android Studio](https://developer.android.com/studio) installieren und
   einmal starten → Setup-Assistent durchklicken (installiert SDK & JDK).
2. In Android Studio: **Settings → Languages & Frameworks → Android SDK** →
   mindestens SDK Platform **34** + Build-Tools installieren.
3. Lizenzen akzeptieren:

```bash
flutter doctor --android-licenses
```

### 1.3 Flutter installieren

```bash
# Apple Silicon
cd ~/Development
unzip flutter_macos_arm64_<version>-stable.zip     # von docs.flutter.dev
# Intel (MacBook Pro/Air vor M1 oder iMac Intel)
unzip flutter_macos_<version>-stable.zip
```

Pfad setzen (Schritt 1.4) und prüfen:

```bash
flutter --version        # muss >= 3.24 zeigen
flutter doctor
```

`flutter doctor` muss für **Xcode**, **Android toolchain** und **Flutter** je
ein ✅ zeigen. Kanäle, die du nicht bauen willst (z. B. Chrome), kannst du
ignorieren. Auf **Intel-Macs** einfach die Intel-Zip verwenden — Flutter baut
dort nativ für x86_64, kein Rosetta nötig.

### 1.4 PATH setzen (einmalig)

```bash
echo 'export PATH="$HOME/Development/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
which flutter            # → .../flutter/bin/flutter
```

---

## 2. Einmalig: Projekt vorbereiten

```bash
cd ~/src
git clone <repo-url> openiptv
cd openiptv
./tool/setup.sh
```

Das Skript macht:

1. `flutter create --platforms=android,ios,macos ...` — erzeugt die nativen
   `android/`, `ios/`, `macos/`-Projekte (nicht eingechecked, Standard).
2. `flutter pub get` — Dependencies.
3. `dart run build_runner build` — erzeugt `lib/core/database/database.g.dart`.
4. macOS-**Entitlements** patcht (Netzwerk für App Sandbox) — nötig, damit die
   App deinen Unraid-Server erreichen darf.
5. Android-Manifest für **Android TV (Leanback)** patcht (D-Pad-Fokus).

Wichtig: Schritt 3 muss ohne Fehler durchlaufen; fehlt `database.g.dart`,
bekommst du beim Kompilieren Fehler à la
`Compiler message: … database.g.dart: No such file`. Dann Skript erneut ausführen.

---

## 3. Backend-URL angeben (wichtig für Sync)

Standardmäßig zeigt die App auf `http://127.0.0.1:8080` (gut nur für Tests
auf dem Mac mit lokal laufendem Backend). Für die **realen Geräte** gibst du
beim Bauen die IP deines Unraid-Servers mit:

```bash
UNRAID=192.168.1.50      # ← deine Unraid-IP (in Unraid: Settings → Network)
```

Jeder Build-Befehl unten bekommt dann diese Defines mit:

```bash
--dart-define=BACKEND=rest --dart-define=BACKEND_URL=http://$UNRAID:8080
```

> Die IP ändert sich seltenst, aber wenn doch → neu bauen. Alternativ: DHCP-
> Reservierung in deinem Router für das Unraid-Board oder ein Hostname.

---

## 4. macOS-App (Intel & Apple Silicon)

### 4.1 Schnelltest (Debug, läuft sofort)

```bash
flutter run -d macos \
  --dart-define=BACKEND=rest --dart-define=BACKEND_URL=http://$UNRAID:8080
```

### 4.2 Release-App bauen

```bash
flutter build macos --release \
  --dart-define=BACKEND=rest --dart-define=BACKEND_URL=http://$UNRAID:8080
```

Ergebnis: `build/macos/Build/Products/Release/open_iptv.app` —
diese App läuft **auf Intel- und Apple-Silicon-Macs** (Universal Binary).

### 4.3 DMG erzeugen (zum „Installieren" auf anderen Macs)

```bash
hdiutil create -volname OpenIPTV \
  -srcfolder build/macos/Build/Products/Release/open_iptv.app \
  -ov -format UDZO OpenIPTV-macOS.dmg
```

Verteilen: Die `.dmg` zu einem anderen Mac kopieren, öffnen, App nach
`/Applications` ziehen. Beim ersten Öffnen unter macOS Gatekeeper:

```bash
xattr -dr com.apple.quarantine /Applications/open_iptv.app
```

(Entwickler-Signing + Notarization sind optional und nur für öffentliche
Verteilung nötig — lokal im Heimnetz reicht `xattr`.)

---

## 5. Android / Android TV (APK)

### 5.1 Universal-APK (läuft auf Telefon **und** Android TV)

```bash
flutter build apk --release \
  --dart-define=BACKEND=rest --dart-define=BACKEND_URL=http://$UNRAID:8080
```

Ergebnis: `build/app/outputs/flutter-apk/app-release.apk`

### 5.2 (Optional) Pro-Architektur gesplittet (kleinere Dateien)

```bash
flutter build apk --release --split-per-abi \
  --dart-define=BACKEND=rest --dart-define=BACKEND_URL=http://$UNRAID:8080
```

→ `app-arm64-v8a-release.apk` (moderne TVs & Phones),
`app-armeabi-v7a-release.apk` (alte Geräte), `app-x86_64-release.apk` (Emulator).

### 5.3 Auf Android TV installieren

Entweder **adb** (TV: Settings → Device Preferences → Debugging → USB/Network
debugging aktivieren):

```bash
adb connect <TV-IP>:5555
adb install build/app/outputs/flutter-apk/app-release.apk
```

oder die APK auf einen USB-Stick / in die Nextcloud kopieren und am TV mit
einem Dateimanager (z. B. FX File Explorer) direkt installieren.
**„Unbekannte Quellen"** am TV einmalig in den Entwickleroptionen erlauben.

### 5.4 (Optional) APK signieren, damit Upgrades sauber installierbar sind

Standardmäßig ist die APK Flutter-auto-signiert (debug keystore) — funktional,
aber bei jedem Rebuild auf demselben Gerät wieder ersetzt durch Neuinstallation.
Für konsistentes Signing:

```bash
keytool -genkey -v -keystore ~/openiptv.keystore \
  -alias openiptv -keyalg RSA -keysize 2048 -validity 10000
```

Dann `android/key.properties` anlegen (nicht einchecken):

```properties
storePassword=***
keyPassword=***
keyAlias=openiptv
storeFile=/Users/du/openiptv.keystore
```

und in `android/app/build.gradle` die `signingConfigs`-Blöcke ergänzen
(Flutter-Doku: „Sign the app"). Danach baut dasselbe APK-Kommando automatisch signiert.

---

## 6. iOS (iPhone / iPad) — IPA

iOS ist der Teil mit dem **Apple-Signing-Rummel**. Zwei Wege:

### 6.1 Schnellweg: unsignierte IPA bauen (zum „Sideloaden")

```bash
flutter build ipa --release --no-codesign \
  --dart-define=BACKEND=rest --dart-define=BACKEND_URL=http://$UNRAID:8080
```

Ergebnis: `build/ios/archive/OpenIPTV.xcarchive` — daraus Paketieren:

```bash
mkdir -p /tmp/Payload
cp -R build/ios/archive/OpenIPTV.xcarchive/Products/Applications/open_iptv.app /tmp/Payload/
cd /tmp && zip -r OpenIPTV.ipa Payload
```

→ `OpenIPTV.ipa` (unsigniert) in `~/src/openiptv/` verschieben.

**Signieren/Installieren am iPhone** — drei Optionen:

| Option | Voraussetzung | Einschränkung |
|---|---|---|
| **Kostenlose Apple ID** (Xcode) | nur Apple ID | App läuft 7 Tage, dann neu |
| **Apple Developer Program** (99 €/Jahr) | Paid Account | TestFlight/App-Store-ready |
| **AltStore/Sidestore** auf Mac | Konto | 7-Tage-Rotation |

**Option A — Xcode (gratis, empfohlen zum Ausprobieren):**

1. iPhone per Kabel an den Mac anschließen; auf dem iPhone einmalig den
   **Developer Mode** aktivieren (Settings → Privacy & Security → Developer Mode).
2. Archiv in Xcode öffnen:
   ```bash
   open build/ios/archive/OpenIPTV.xcarchive
   ```
3. Im **Organizer** links das Archiv wählen → **Distribute App** →
   *Custom* → *Development* → als Team deine Apple ID auswählen.
   Xcode legt automatisch ein Free-Provisioning-Profil an; die Bundle-ID
   (z. B. `com.deinname.openiptv`) kannst du kurz bestätigen/ändern.
4. Vor der Verteilung in Xcode einmalig: **Signing & Capabilities** des
   Runner-Targets prüfen (Team gesetzt).
5. Exportierte App über **Window → Devices and Simulators** auf das iPhone
   installieren oder per Finder synchronisieren.
6. Auf dem iPhone: **Settings → General → VPN & Device Management** →
   dein Profil trusten (einmalig). Danach erscheint die App auf dem
   Home-Screen.

**Option B — Paid Account + TestFlight (für Dauerbetrieb):**
Den Archiv-Dialog **Distribute App → App Store Connect** wählen und über
TestFlight auf die Geräte verteilen — Beta-Builds laufen bis zu 90 Tage,
Release-Builds unbefristet.

---

## 7. Fehlerbehebung

| Problem | Ursache / Lösung |
|---|---|
| `database.g.dart: No such file` / Codegen-Fehler | `./tool/setup.sh` nicht gelaufen → nachholen (`flutter pub get` + `dart run build_runner build`). |
| macOS-Build bricht bei Code-Signing ab | Temporär `--no-codesign` ans Kommando; dauerhaft in Xcode ein Team eintragen (Runner-Target → Signing & Capabilities). |
| Mac-App: „Verbindung zum Server fehlgeschlagen" | Entitlements fehlen → `./tool/setup.sh` erneut ausführen (patcht `macos/Runner/*.entitlements`, fügt `network.client`/`network.server` hinzu). |
| Gatekeeper am Mac blockiert die .app | `xattr -dr com.apple.quarantine /Applications/open_iptv.app` |
| Android: `Install failed` auf TV | TV: „Unbekannte Quellen" erlaubt? Vorherige Installation mit anderer Signatur? → App vorher deinstallieren. |
| Android: SDK-Version Fehler | `flutter build` meldet, welche API-Level fehlen → Android Studio SDK-Manager öffnen, fehlende Platform installieren. |
| iOS: `No profiles for '…' were found` | Signing-Team in Xcode eintragen (Runner-Target → Signing & Capabilities), dann Distribute App erneut (Abschnitt 6.1, Option A). |
| Sync läuft nicht auf dem Gerät | BACKEND_URL geändert? IP falsch? Backend-Container läuft? Siehe [INSTALL.md, Teil 3](INSTALL.md#teil-3--troubleshooting). |
| Nach Code-Änderungen baut es nicht | `flutter clean && ./tool/setup.sh` |

---

## 8. Zusammenfassung — Copy-&-Paste

```bash
# einmalig
git clone <repo-url> openiptv && cd openiptv && ./tool/setup.sh
UNRAID=192.168.1.50
DEF="--dart-define=BACKEND=rest --dart-define=BACKEND_URL=http://$UNRAID:8080"

# macOS
flutter build macos --release $DEF
hdiutil create -volname OpenIPTV -srcfolder build/macos/Build/Products/Release/open_iptv.app -ov -format UDZO OpenIPTV-macOS.dmg

# Android TV
flutter build apk --release $DEF
adb connect <TV-IP>:5555 && adb install build/app/outputs/flutter-apk/app-release.apk

# iOS (unsigniert, dann via Xcode signieren)
flutter build ipa --release --no-codesign $DEF
```
