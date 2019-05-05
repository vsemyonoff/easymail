#!/usr/bin/env bash
################################################################################
# Config
################################################################################
#

################################################################################
# Main
################################################################################
#
# PROJECT="easymail"

# # Override defaults from config if it exists
# USER_CONFIG="${XDG_CONFIG_HOME}/${PROJECT}.conf"
# [[ -r "${USER_CONFIG}" ]] && source "${USER_CONFIG}"

# # Data folders
# LOGS_DIR="${XDG_LOG_HOME:-${XDG_HOME:-${HOME}/.local}/var/log}/${PROJECT}"
# MAILDB_DIR="$(notmuch config get database.path)"

# # Redirect all output to log file
# log="${LOGS_DIR}/index.log"
# exec &> >(tee -a "${log}")

# Tag all 'new' messages with 'account' and 'folder' names
shopt -s nullglob; accounts=($(easymail list))
for account in "${accounts[@]}"; do
    folders=("$(easymail get ${account} maildir)"/*)
    folder=""
    for folder in "${folders[@]}"; do
        lable="${folder##*/}"
        notmuch tag +${account} +${lable} -- "tag:new and folder:${account}/${lable}"
    done
done

# Unset 'unread' tag from archive/drafts/sent/trash folders
notmuch tag -unread -- "tag:new and folder:\"/[^\/]+\/(Archive|Drafts|Sent|Trash)/\""
new_unread=$(notmuch count -- tag:new and tag:unread)

# Unset 'new' tag from all new messages
notmuch tag -new -- tag:new

# Notify user about new mail (if any)
if [[ ${new_unread} > 0 ]]; then
    notify-send "Mail Delivery" "You have ${new_unread} new letters"
fi
