#!/usr/bin/env bash
################################################################################
# Config
################################################################################
#
# Pairs:
#     'tag' name -- 'notmuch tag' args to apply after 'tag' processing
deleted=("deleted" "")
draft=("newdraft" "--remove-all +draft +new")
readed=("readed" "-readed -unread")
sent=("newsent" "--remove-all +new")
trashed=("trashed" "--remove-all +new")
unreaded=("unreaded" "-unreaded +unread")

# Tags combined
tags=(deleted draft readed sent trashed unreaded)

# Deleted messages handler
function deleted_handler () {
    [[ ${#} != 3 ]] && echo "invalid handler call" && return 1

    local f="${1}" # file name

    # Just remove
    rm -fv "${f}"
}

# Trashed messages handler
function trashed_handler () {
    [[ ${#} != 3 ]] && echo "invalid handler call" && return 1

    local f="${1}" # file name
    local a="${2}" # account name
    local c="${3}" # channel name

    if [[ "${c}" != "Trash" ]]; then
        # Create duplicate in Trash folder
        cat "${f}" | notmuch insert --create-folder --folder="${a}/Trash"
    fi

    # Add 'Trash' to affected channels (only once)
    for (( i=0; i<${#mod_accounts[@]}; i++ )); do
        if [[ "${mod_accounts[${i}]}" == "${a}" ]]; then
            if [[ ! "${mod_channels[${i}]}" =~ (.*)?Trash(.*)? ]]; then
                mod_channels[${i}]="${mod_channels[${i}]} Trash"
            fi
            break
        fi
    done

    # Remove original file
    rm -fv "${f}"
}

################################################################################
# Main
################################################################################
#
PROJECT="easymail"

# Override defaults from config if it exists
USER_CONFIG="${XDG_CONFIG_HOME}/${PROJECT}.conf"
[[ -r "${USER_CONFIG}" ]] && source "${USER_CONFIG}"

# Data folders
LOGS_DIR="${XDG_LOG_HOME:-${XDG_HOME:-${HOME}/.local}/var/log}/${PROJECT}"
MAILDB_DIR="$(notmuch config get database.path)"

# Redirect all output to log file
log="${LOGS_DIR}/index.log"
exec &> >(tee -a "${log}")

# Changed accounts/channels list
mod_accounts=()
mod_channels=()

for tag in "${tags[@]}"; do
    # ??? , but it works :)
    tag_name=$(eval echo \${${tag}[0]}); [[ -z "${tag_name}" ]] && continue
    tag_args=$(eval echo \${${tag}[1]})

    mod_files=($(notmuch search --output=files --format=text -- "tag:${tag_name}"))

    handler="${tag_name}_handler"
    if [[ ! $(type -t "${handler}") == "function" ]]; then
        unset handler
    fi

    if [[ ${#mod_files[@]} > 0 ]]; then
        # Parse affected accounts/channels and move to Trash
        for file in "${mod_files[@]}"; do
            # Get account from file name
            account="${file#${MAILDB_DIR}/}"
            account="${account%%/*}"
            if [[ ! "${mod_accounts[*]}" =~ (.*)?${account}(.*)? ]]; then
                mod_accounts+=("${account}")
            fi

            # Get channel from file name && assign channel list to account
            channel="${file#${MAILDB_DIR}/${account}/}"
            channel="${channel%%/*}"
            for (( i=0; i<${#mod_accounts[@]}; i++ )); do
                if [[ "${mod_accounts[${i}]}" == "${account}" ]]; then
                    if [[ ! "${mod_channels[${i}]}" =~ (.*)?${channel}(.*)? ]]; then
                        mod_channels[${i}]="${mod_channels[${i}]} ${channel}"
                    fi
                    break # we've found account index
                fi
            done

            # Call tag handler function if provided
            [[ -v handler ]] && ${handler} "${file}" "${account}" "${channel}"
        done

        ${tag_args:+notmuch tag ${tag_args} -- "tag:${tag_name}"}
    fi
done

# Sync changed accounts/channels in background
for (( i=0; i<${#mod_accounts[@]}; i++ )); do
    easymail sync --push ${mod_accounts[${i}]} ${mod_channels[${i}]}
done
