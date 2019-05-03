#!/usr/bin/env bash

# Redirect all output to log file
log_dir="${XDG_LOG_HOME:-${XDG_HOME:-${HOME}/.local}/var/log}/easymail"
log="${log_dir}/pre-new.log"
exec &> >(tee "${log}")

maildb_dir="$(notmuch config get database.path)"
trashed=($(notmuch search --output=files --format=text -- "tag:trashed"))

if [[ ${#trashed[@]} > 0 ]]; then
    # Parse affected accounts/channels and move to Trash
    for file in "${trashed[@]}"; do
        # Get account from file name
        account="${file#${maildb_dir}/}"
        account="${account%%/*}"
        if [[ ! "${accounts[*]}" =~ (.*)?${account}(.*)? ]]; then
            accounts+=("${account}")
        fi

        # Get channel from file name && assign channel list to account
        channel="${file#${maildb_dir}/${account}/}"
        channel="${channel%%/*}"
        for (( i=0; i<${#accounts[@]}; i++ )); do
            if [[ "${accounts[${i}]}" == "${account}" ]]; then
                if [[ ! "${channels[${i}]}" =~ (.*)?${channel}(.*)? ]]; then
                    channels[${i}]="${channels[${i}]} ${channel}"
                fi
                break # we've found account index
            fi
        done

        if [[ "${channel}" != "Trash" ]]; then
            # Create duplicate in Trash folder
            cat "${file}" | notmuch insert --create-folder --folder="${account}/Trash"
        fi

        # Remove original file
        rm -fv "${file}"
    done

    # Unset all tags and set 'new' to trashed messages
    notmuch tag --remove-all +new -- "tag:trashed"

    # Push per account/channel changes
    for (( i=0; i<${#accounts[@]}; i++ )); do
        if [[ ! "${channels[${i}]}" =~ (.*)?Trash(.*)? ]]; then
            channels[${i}]="${channels[${i}]} Trash"
        fi
        easymail sync ${accounts[${i}]} ${channels[${i}]}
    done
fi
