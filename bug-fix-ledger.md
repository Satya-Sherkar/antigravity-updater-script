# Bug Fix Ledger — `install-antigravity-ide.sh`

This file tracks bugs that were found and fixed during development of the
Antigravity IDE installer script. For newly discovered/unresolved issues, see
[`bug_fix_log.md`](./bug_fix_log.md).

---

| ID      | Problem | Resolution |
|---------|---------|------------|
| BUG-001 | `pkill -f "Antigravity IDE"` could kill this installer process. | Fixed by matching only known Antigravity installation paths instead of the broad display name. |
| BUG-002 | Arbitrary icon/logo search selected extension icons instead of the app icon. | Fixed by using the bundled Antigravity SVG explicitly via a known path. |
| BUG-003 | `chrome-sandbox` lacked root ownership and the SUID `4755` bit. | Fixed with `chown root:root` + `chmod 4755` and post-set verification. |
| BUG-004 | `chmod -R a+rX` does not set the SUID sandbox bit (strips it on directories). | Fixed by configuring the sandbox in a dedicated explicit step after the recursive chmod. |
| BUG-005 | Archive extraction could create an unexpected nested directory, causing the app to be installed one level too deep. | Fixed by detecting the application root directory and copying its contents into the destination. |
| BUG-006 | The desktop launcher could point to a guessed or stale executable and icon path. | Fixed by resolving the installed executable path dynamically and using the standard icon path. |
| BUG-007 | Purge mode and normal update behaviour were mixed — user data could be deleted unintentionally. | Fixed by keeping user-data deletion strictly behind the `--purge-data` flag. |
| BUG-008 | Failed installs could leave temporary files in `$DOWNLOAD_DIR`. | Fixed with `cleanup()` and `on_error` traps that remove `$EXTRACT_DIR` and `$STAGE_DIR` on any exit. |
| BUG-009 | `~/.local/bin` may not be in `$PATH`, so the `antigravity-ide` CLI link would be unreachable. | Fixed by detecting when `~/.local/bin` is absent from `$PATH` and appending the export to `~/.bashrc` / `~/.zshrc`. |
| BUG-010 | Stale desktop and icon caches caused the launcher to not appear or use an old icon. | Fixed by invoking `gtk-update-icon-cache` and `update-desktop-database` when those tools are available. |
| BUG-011 | Invalid or truncated downloads could reach the extraction step and fail mid-install. | Fixed with URL scheme validation, a non-empty file check (`-s`), and `tar -tzf` integrity validation before extraction. |
| BUG-012 | `cp` could create an unwanted nested application directory inside the destination. | Fixed by copying `"$APP_SOURCE"/.` (trailing slash-dot) into the destination to copy *contents*, not the directory itself. |
| BUG-013 | Running IDE processes could interfere with file replacement during update. | Fixed with safe graceful (`SIGTERM`) then forced (`SIGKILL`) termination, scoped to known installation paths only. |
| BUG-014 | Replacing the live installation before validation could break an existing working install if the new archive was bad. | Fixed by extracting and staging to `$STAGE_DIR` first, and only replacing the live installation after staging succeeds. |
| BUG-015 | A failed replacement could permanently lose the old installation with no rollback. | Fixed by moving the old installation to a timestamped backup directory before replacing, and removing the backup only after final verification passes. |
