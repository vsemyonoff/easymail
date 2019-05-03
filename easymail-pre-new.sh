#!/usr/bin/env bash

deleted_count=$(notmuch search -- tag:deleted)
maildb_dir="$(notmuch config get database.path)"

if [[ ${deleted_count} > 0 ]]; then
    files+=($(notmuch search --output=files --format=text tag:deleted))
    for file in "${files[@]}"; do
        account=${file#${maildb_dir}/}
        account=${account%%/*}
        if [[ ! "${accounts[*]}" =~ (.*)?${account}(.*)? ]]; then
            accounts+=("${account}")
        fi

        channel="${file#${maildb_dir}/${account}/}"
        channel="${channel%%/*}"
        for (( i=0; i<${#accounts[@]}; i++ )); do
            if [[ ${accounts[${i}]} == "${account}" ]]; then
                if [[ ! ${channels[${i}]} =~ (.*)?${channel}(.*)? ]]; then
                    channels[${i}]+="${channels[${i}]} ${channel}"
                fi
                break # we've found account index
            fi
        done
    done
    unset channel
    unset account

    # Delete messages tagged as 'deleted'
    rm "${files[@]}"

    # Sync only affected accounts changes to server
    for (( i=0; i<${#accounts[@]}; i++ )); do
        easymail sync --push ${accounts[${i}]} ${channels[${i}]}
    done
fi
