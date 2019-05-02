#!/usr/bin/env bash

accounts=($(easymail list))

shopt -s nullglob
for account in "${accounts[@]}"; do
    # Tag all 'new' with 'account' and 'folder' names
    folders=("$(easymail get ${account} maildir)"/*)
    folder=""
    for folder in "${folders[@]}"; do
        lable="${folder##*/}"
        notmuch tag +${account} +${lable} -- tag:new and folder:${account}/${lable}
    done

    # Unread my/drafts/sent/spam/trash mail from unread
    me="$(easymail get ${account} email)"
    notmuch tag -unread -- "tag:new and (from:${me} or folder:${account}/Drafts or folder:${account}/Sent or folder:${account}/Spam or folder:${account}/Trash)"

    new_unread=$(notmuch count -- tag:new and tag:unread)
done

# Clear new tag
notmuch tag -new -- tag:new

# Notify user
if [[ ${new_unread} > 0 ]]; then
    notify-send "Mail Delivery" "You have ${new_unread} new letters"
fi
