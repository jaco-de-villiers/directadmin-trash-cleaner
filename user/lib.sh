#!/bin/bash
# Author: Jaco De Villiers
# Shared helpers for the Trash Cleaner plugin.
# Runs as the logged-in DirectAdmin user, so it can only ever touch that user's files.

# Mail folder names treated as "trash" (Maildir++ folder names, leading dot included).
# Covers Roundcube/Dovecot defaults plus common Outlook/Apple/Thunderbird variants.
TRASH_FOLDERS=(".Trash" ".INBOX.Trash" ".Deleted Items" ".Deleted Messages" ".INBOX.Deleted Items" ".INBOX.Deleted Messages")

USER_HOME="${HOME:-}"
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
	USER_HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
fi
TOKEN_FILE="$USER_HOME/.trash_cleaner_token"

html_escape() {
	local s="$1"
	s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; s="${s//\"/&quot;}"
	printf '%s' "$s"
}

human_size() {
	awk -v b="${1:-0}" 'BEGIN{
		split("B KB MB GB TB",u," "); i=1
		while (b>=1024 && i<5){b/=1024;i++}
		if (i==1) printf "%d %s", b, u[i]; else printf "%.2f %s", b, u[i]
	}'
}

# Sum of apparent file sizes (bytes) and file count under a directory, no symlink following.
dir_bytes() { find -P "$1" -mindepth 1 -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END{print s+0}'; }
dir_files() { find -P "$1" -mindepth 1 -type f 2>/dev/null | wc -l; }

# Emits one line per trash location: TYPE|LABEL|PATH
# PATH is a directory whose *contents* are to be emptied.
list_locations() {
	# 1. File Manager trash
	if [ -d "$USER_HOME/.trash" ] && [ ! -L "$USER_HOME/.trash" ]; then
		echo "files|File Manager trash|$USER_HOME/.trash"
	fi

	# 2. System account mailbox (~/Maildir)
	local f
	for f in "${TRASH_FOLDERS[@]}"; do
		if [ -d "$USER_HOME/Maildir/$f" ] && [ ! -L "$USER_HOME/Maildir/$f" ]; then
			echo "mail|$(id -un) (main account) - ${f#.}|$USER_HOME/Maildir/$f"
		fi
	done

	# 3. Every POP/IMAP mailbox on every domain: ~/imap/<domain>/<box>/Maildir
	local d box name
	[ -d "$USER_HOME/imap" ] || return 0
	for d in "$USER_HOME"/imap/*/; do
		[ -d "$d" ] && [ ! -L "${d%/}" ] || continue
		for box in "$d"*/; do
			[ -d "${box}Maildir" ] && [ ! -L "${box}Maildir" ] || continue
			name="$(basename "$box")@$(basename "$d")"
			for f in "${TRASH_FOLDERS[@]}"; do
				if [ -d "${box}Maildir/$f" ] && [ ! -L "${box}Maildir/$f" ]; then
					echo "mail|$name - ${f#.}|${box}Maildir/$f"
				fi
			done
		done
	done
}

# Empties one location. For mail folders only message files in cur/ and new/ are removed,
# so the folder itself, its subscriptions and Dovecot metadata stay intact.
empty_location() {
	local type="$1" path="$2"
	if [ "$type" = "files" ]; then
		find -P "$path" -mindepth 1 -delete 2>/dev/null
	else
		find -P "$path/cur" "$path/new" -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null
		# Drop the Dovecot index cache for this folder so the client sees an empty folder at once.
		rm -f "$path"/dovecot.index "$path"/dovecot.index.cache "$path"/dovecot.index.log* 2>/dev/null
		# Force Maildir++ quota recalculation for the mailbox (Dovecot rebuilds maildirsize).
		rm -f "$(dirname "$path")/maildirsize" 2>/dev/null
	fi
}

# Size and count for a location (mail: only the message files that would be removed).
loc_stats() {
	local type="$1" path="$2"
	if [ "$type" = "files" ]; then
		echo "$(dir_bytes "$path") $(dir_files "$path")"
	else
		find -P "$path/cur" "$path/new" -mindepth 1 -maxdepth 1 -type f -printf '%s\n' 2>/dev/null \
			| awk '{s+=$1;n++} END{print s+0, n+0}'
	fi
}

get_param() {
	# Reads a parameter from the query string or POST data passed by DirectAdmin.
	local key="$1" pair
	local IFS='&'
	for pair in ${QUERY_STRING:-} ${POST:-}; do
		if [ "${pair%%=*}" = "$key" ]; then
			printf '%s' "${pair#*=}" | tr -cd 'A-Za-z0-9_-'
			return
		fi
	done
}

page_style() {
cat <<'CSS'
<style>
.tc-wrap{max-width:900px;font-family:inherit}
.tc-wrap h2{display:flex;align-items:center;gap:10px;margin:0 0 6px}
.tc-sub{opacity:.75;margin:0 0 18px}
.tc-total{display:flex;gap:16px;flex-wrap:wrap;margin:0 0 18px}
.tc-card{flex:1 1 200px;border:1px solid rgba(127,127,127,.3);border-radius:8px;padding:14px 16px}
.tc-card .n{font-size:26px;font-weight:600;line-height:1.2}
.tc-card .l{opacity:.7;font-size:13px}
.tc-table{width:100%;border-collapse:collapse;margin:0 0 18px}
.tc-table th,.tc-table td{text-align:left;padding:8px 10px;border-bottom:1px solid rgba(127,127,127,.2)}
.tc-table td.num,.tc-table th.num{text-align:right;white-space:nowrap}
.tc-btn{display:inline-flex;align-items:center;gap:8px;background:#2f7de1;color:#fff;border:0;border-radius:6px;padding:10px 18px;font-size:15px;cursor:pointer;text-decoration:none}
.tc-btn:hover{background:#2468c0;color:#fff}
.tc-btn.sec{background:transparent;color:inherit;border:1px solid rgba(127,127,127,.4)}
.tc-ok{border-left:4px solid #2fa36b;padding:10px 14px;margin:0 0 18px;background:rgba(47,163,107,.08)}
.tc-empty{padding:24px;text-align:center;opacity:.75;border:1px dashed rgba(127,127,127,.4);border-radius:8px}
</style>
CSS
}

BROOM_SVG='<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20.5 2.5 L12.2 10.8"/><path d="M10.4 9.4 L14.6 13.6"/><path d="M10.4 9.4 C7.6 10.2 5.2 12.4 3.5 16.2 L7.8 20.5 C11.6 18.8 13.8 16.4 14.6 13.6 Z"/><path d="M6.2 13.4 L9.4 16.6"/><path d="M5 15.6 L8.2 18.8"/><path d="M18.5 15.5 v3 M17 17 h3"/></svg>'
