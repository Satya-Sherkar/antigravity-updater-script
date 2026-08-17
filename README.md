# Antigravity IDE Installer / Updater Guide

## 1. Save and make executable

```bash
chmod +x install-antigravity-ide.sh
```

## 2. Normal update

```bash
./install-antigravity-ide.sh
```

This replaces the application and preserves user settings/data.

The script will ask for the current official Antigravity Linux `.tar.gz` URL. For your x86_64 machine, choose the Linux x86_64 build.

## 3. Full purge

```bash
./install-antigravity-ide.sh --purge-data
```

This also removes common Antigravity settings/cache/user-data directories. Use it only when you want a fresh IDE profile.

## 4. Supply the URL directly

```bash
./install-antigravity-ide.sh --url "YOUR_OFFICIAL_TARBALL_URL"
```

Or:

```bash
./install-antigravity-ide.sh --purge-data --url "YOUR_OFFICIAL_TARBALL_URL"
```

## 5. Show help

```bash
./install-antigravity-ide.sh --help
# or
./install-antigravity-ide.sh -h
```

Prints a full usage reference and exits without making any changes.

## 6. Start Antigravity

```bash
antigravity-ide
```

If the command is not found immediately after installation, open a new terminal.

## 7. Verify the sandbox

```bash
stat -c '%U:%G %a' /opt/antigravity-ide/chrome-sandbox
```

Expected:

```text
root:root 4755
```

## 8. Verify the icon

The script uses the bundled Antigravity SVG:

```text
/opt/antigravity-ide/resources/app/out/vs/platform/browserOnboarding/static/antigravity.svg
```

It installs it as:

```text
~/.local/share/icons/hicolor/scalable/apps/antigravity-ide.svg
```

The desktop launcher contains:

```ini
Icon=antigravity-ide
```

If GNOME still shows an old icon:

```bash
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor 2>/dev/null || true
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

If necessary, log out and back in.

## 9. Important behavior

Normal:

```bash
./install-antigravity-ide.sh
```

- application replaced
- settings preserved
- extensions/profile preserved

Purge:

```bash
./install-antigravity-ide.sh --purge-data
```

- application replaced
- common user data removed
- settings/cache/extensions may be lost

## 10. Bugs fixed

The full history of bugs found and fixed during development (BUG-001 → BUG-015) is
documented in [`bug-fix-ledger.md`](./bug-fix-ledger.md). Key fixes include:

- installer killing itself with `pkill -f`
- incorrect extension icon being selected
- missing Electron SUID sandbox configuration
- incorrect archive nesting
- stale/incorrect desktop launcher
- stale icon cache
- unsafe purge behavior
- incomplete cleanup on errors
- `~/.local/bin` PATH handling
- validating before replacing the current application
- keeping a temporary backup until the new install is verified

## 11. Repository files

| File | Description |
|------|-------------|
| [`install-antigravity-ide.sh`](./install-antigravity-ide.sh) | Main installer / updater script |
| [`bug-fix-ledger.md`](./bug-fix-ledger.md) | History of bugs found and fixed (BUG-001 → BUG-015) |
| [`README.md`](./README.md) | This guide |
