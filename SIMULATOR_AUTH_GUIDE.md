# Simulator Authentication Setup Guide
## GroceryGenius - Option 3: Echte Authentifizierung für Simulator

### 📱 Übersicht

Die App unterstützt jetzt **drei Authentifizierungsmodi**:

1. **Magic Link** (Geräte): E-Mail mit Login-Link
2. **Email & Password** (Simulator): Direkte Anmeldung 
3. **Auto** (Empfohlen): Automatische Erkennung basierend auf Umgebung

### 🔧 Ersteinrichtung

#### 1. Supabase Test-Accounts erstellen

Öffne dein Supabase Dashboard → Authentication → Users:

**Developer Account:**
- Email: `developer@grocerygenius.app`
- Password: `DevTest123!`
- ✅ Email Confirm: true

**Tester Account:**
- Email: `tester@grocerygenius.app` 
- Password: `TestUser456!`
- ✅ Email Confirm: true

**Demo Account:**
- Email: `demo@grocerygenius.app`
- Password: `DemoPass789!`
- ✅ Email Confirm: true

#### 2. Supabase Email-Provider Settings

Dashboard → Authentication → Providers → Email:
- ✅ Enable email provider
- ✅ Confirm email: Optional (für Test-Accounts)
- ✅ Enable sign ups: true

### 📲 Verwendung im Simulator

#### Auto-Modus (Empfohlen)
1. App starten im iOS Simulator
2. Auth-Modus steht automatisch auf "Auto" 
3. Password-Feld wird automatisch angezeigt
4. **Quick-Test-Account Buttons** erscheinen unterhalb der Felder
5. Einen der Test-Account-Buttons antippen → Felder werden automatisch ausgefüllt
6. "Mit Passwort anmelden" antippen

#### Manueller Modus
1. Auth-Modus auf "Email & Password" umstellen
2. Email und Password eingeben
3. **"Mit Passwort anmelden"** für bestehende Accounts
4. **"Neues Konto erstellen"** für neue Registrierung

### 📱 Verwendung auf echten Geräten

#### Auto-Modus (Empfohlen)
1. App starten auf iPhone/iPad
2. Auth-Modus steht automatisch auf "Auto"
3. Nur Email-Feld wird angezeigt
4. Email eingeben → "Magic Link senden"
5. E-Mail öffnen → Link antippen → automatisches Login

#### Manueller Modus
- Magic Link: Funktioniert wie gewohnt
- Email & Password: Funktioniert auch auf Geräten

### 🚀 Entwickler-Workflow

```swift
// Simulator erkennen
#if targetEnvironment(simulator)
    // Verwende Email/Password
#else
    // Verwende Magic Link
#endif
```

#### Schnelle Test-Accounts
Im Simulator werden automatisch **Quick-Select Buttons** angezeigt:
- **Developer Test Account** 
- **QA Tester Account**
- **Demo/Showcase Account**

Ein Klick füllt Email + Passwort automatisch aus.

### 🛠 Technische Details

#### Neue AppSessionViewModel Methoden:
```swift
func signInWithEmailPassword(email: String, password: String)
func signUpWithEmailPassword(email: String, password: String) 
func signInWithEmailOTP(email: String) // Bestehend
```

#### Neue AuthView Features:
- **Segmented Control** für Auth-Modus-Auswahl
- **Conditional Password Field** je nach Modus
- **Auto-Detection** basierend auf `targetEnvironment(simulator)`
- **Quick Test Account Selection** nur im Simulator sichtbar

#### Lokalisierung:
Alle neuen UI-Elemente sind vollständig lokalisiert (EN/DE).

### ✅ Vorteile für iOS-Testing

1. **Keine Magic-Link Probleme** im Simulator
2. **Schnelle Test-Account-Auswahl** spart Zeit
3. **Auto-Detection** funktioniert überall optimal
4. **Echte Authentifizierung** - keine Mock-Daten
5. **Produktionsnahe Tests** möglich

### 🔒 Sicherheit

- Test-Accounts nur in `#if DEBUG && targetEnvironment(simulator)`
- Echte Supabase-Authentifizierung mit RLS
- Keine Hard-coded Credentials in Production builds
- Auto-Detection nutzt Compile-time Flags

### 📝 Nächste Schritte

1. **Test-Accounts in Supabase erstellen** (siehe oben)
2. **App im Simulator starten**
3. **Quick-Test-Account Button verwenden**
4. **iOS-Styling-Unterschiede testen** zwischen iOS 18/26
5. **App auf echtem Gerät testen** mit Magic Links

---

🎯 **Jetzt kannst du die iOS-Version-Styling-Unterschiede perfekt im Simulator testen!**