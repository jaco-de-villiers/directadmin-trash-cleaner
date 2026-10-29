#!/bin/bash
# Author: Jaco De Villiers
# Run by the DirectAdmin plugin manager on install.
DIR=/usr/local/directadmin/plugins/trash_cleaner
chown -R diradmin:diradmin "$DIR"
chmod 755 "$DIR" "$DIR"/user "$DIR"/hooks "$DIR"/images "$DIR"/scripts
chmod 755 "$DIR"/user/index.html "$DIR"/user/lib.sh
chmod 644 "$DIR"/hooks/*.html "$DIR"/images/* "$DIR"/plugin.conf
chmod 700 "$DIR"/scripts/*.sh
echo "Trash Cleaner installed."
exit 0
