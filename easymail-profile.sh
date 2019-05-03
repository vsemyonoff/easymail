# Primary name/email
NAME="Vasya Petelkin"
EMAIL="vpetelkin@fastmail.com"

# Mail storage
MAILDIR="${XDG_HOME:-"${HOME}/.local"}/var/spool/mail"

# Notmuch
NOTMUCH_CONFIG="${XDG_CONFIG_HOME}/notmuch.conf"

xexport NAME EMAIL MAILDIR NOTMUCH_CONFIG
