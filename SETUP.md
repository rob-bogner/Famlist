# Famlist - Lokale Entwicklungsumgebung einrichten

## Supabase Credentials konfigurieren

Die App benötigt Supabase-Credentials zum Ausführen. Diese sollten **niemals** ins Repository committed werden.

### Option 1: Secrets.plist (Empfohlen für lokale Entwicklung)

1. Kopiere `Secrets.example.plist` zu `Secrets.plist`:
   ```bash
   cp Secrets.example.plist Secrets.plist
   ```

2. Öffne `Secrets.plist` und trage deine Credentials ein:
   ```xml
   <key>SUPABASE_URL</key>
   <string>https://YOUR-PROJECT-REF.supabase.co</string>
   <key>SUPABASE_ANON_KEY</key>
   <string>YOUR-ANON-KEY</string>
   ```

3. Die Datei ist bereits in `.gitignore` und wird nicht committed.

### Option 2: Xcode Scheme Environment Variables (Lokal)

1. In Xcode: `Product > Scheme > Edit Scheme...` (oder `⌘ + <`)
2. Wähle **Run** in der linken Sidebar
3. Wähle den Tab **Arguments**
4. Im Abschnitt **Environment Variables** klicke auf `+`
5. Füge hinzu:
   - **Name:** `SUPABASE_URL`  
     **Value:** `https://YOUR-PROJECT-REF.supabase.co`
   - **Name:** `SUPABASE_ANON_KEY`  
     **Value:** `YOUR-ANON-KEY`

**⚠️ WICHTIG:** Wenn du Option 2 verwendest, stelle sicher, dass deine Scheme-Datei **NICHT** in `xcshareddata/` liegt, sondern in `xcuserdata/` (benutzerspezifisch).

### Option 3: Xcode Build Configuration (Production)

Für Production Builds sollten die Credentials über Build Configuration oder CI/CD Environment Variables bereitgestellt werden, niemals hardcodiert.

## Credentials erhalten

Deine Supabase-Credentials findest du:
1. Öffne das [Supabase Dashboard](https://app.supabase.com)
2. Wähle dein Projekt
3. Gehe zu **Settings** > **API**
4. Kopiere:
   - **Project URL** → `SUPABASE_URL`
   - **anon/public key** → `SUPABASE_ANON_KEY`

## Sicherheitshinweise

- ✅ `Secrets.plist` ist in `.gitignore` - wird nicht committed
- ✅ Scheme-Dateien in `xcuserdata/` sind in `.gitignore`
- ❌ **NIEMALS** Credentials in `xcshareddata/` Dateien einfügen
- ❌ **NIEMALS** Credentials direkt im Code hardcoden
- ❌ **NIEMALS** `.gitignore` Regeln entfernen, die Secrets schützen

## Bereits committed?

Falls Credentials versehentlich committed wurden:
1. **Rotate sofort die Keys** im Supabase Dashboard
2. Entferne sie aus der Git-Historie (siehe Git-Dokumentation für BFG Repo-Cleaner)
3. Aktualisiere alle Entwickler mit den neuen Keys

