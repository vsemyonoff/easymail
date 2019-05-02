#!/usr/bin/env bash

shopt -s nullglob; accounts=($(easymail list))

# Tag all 'new' with 'account' and 'folder' names
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
