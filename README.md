# Trash Cleaner for DirectAdmin

A user-level DirectAdmin plugin by **Jaco De Villiers**.

Adds a broom icon to the user panel. One click shows everything sitting in the user's trash, and **Clean now** empties it and reports how much space was freed.

## What it cleans

- **File Manager trash** (`~/.trash`)
- **Trash / Deleted Items folder of every mailbox** on every domain the user owns (`~/imap/<domain>/<mailbox>/Maildir`), plus the main system mailbox (`~/Maildir`)

Recognised mail folders: `Trash`, `INBOX.Trash`, `Deleted Items`, `Deleted Messages` (and their `INBOX.` variants). Edit `TRASH_FOLDERS` in `user/lib.sh` to change this.

## How it works

1. The user opens **Trash Cleaner** and sees a breakdown per location (items and size) with a total.
2. **Clean now** asks for confirmation, then deletes the items permanently.
3. A summary shows the total space cleared and the items removed per location.

Safety:

- Runs as the logged-in user, so it can only ever touch that user's own files.
- Symlinks are never followed.
- The clean action needs a one-time token from the preview page, so a stray link cannot trigger a clean-up.
- Mail folders themselves are kept; only messages inside them are removed. Dovecot indexes and the `maildirsize` quota file are reset so usage updates correctly.

## Install

On the server as root:

```bash
cd /usr/local/directadmin/plugins
git clone https://github.com/jaco-de-villiers/directadmin-trash-cleaner.git trash_cleaner
cd trash_cleaner && bash scripts/install.sh
sed -i 's/^installed=.*/installed=yes/; s/^active=.*/active=yes/' plugin.conf
```

Or tar it up (`tar czf trash_cleaner.tar.gz -C trash_cleaner .`) and upload it at **Admin → Plugin Manager → Add plugin**.

Then enable it under **Plugin Manager**. Users find it at **CMD_PLUGINS/trash_cleaner**.

## Files

```
plugin.conf            plugin metadata
hooks/user_txt.html    user menu link
images/user_icon.svg   broom icon
user/index.html        preview + clean page (bash)
user/lib.sh            shared helpers
scripts/install.sh     sets ownership and permissions
scripts/uninstall.sh
```

## Licence

MIT © Jaco De Villiers. See [LICENSE](LICENSE).
