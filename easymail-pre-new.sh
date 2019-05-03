#!/usr/bin/env bash
################################################################################
# Config
################################################################################
#
# Pairs:
#     'tag' name -- 'notmuch tag' args to apply after 'tag' processing
trashed=("trashed" "--remove-all +new")
readed=("readed" "-readed")

# Tags combined
tags=(readed trashed)

# Trashed messages handler
trash_added=""
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
    if [[ -z "${trash_added=}" ]]; then
        for (( i=0; i<${#accounts[@]}; i++ )); do
            if [[ "${accounts[${i}]}" == "${a}" ]]; then
                if [[ ! "${channels[${i}]}" =~ (.*)?Trash(.*)? ]]; then
                    channels[${i}]="${channels[${i}]} Trash"
                fi
                trash_added="true"
                break
            fi
        done
    fi

    # Remove original file
    rm -fv "${f}"
}

################################################################################
# Main
################################################################################
#
# Redirect all output to log file
log_dir="${XDG_LOG_HOME:-${XDG_HOME:-${HOME}/.local}/var/log}/easymail"
log="${log_dir}/pre-new.log"
exec &> >(tee "${log}")

maildb_dir="$(notmuch config get database.path)"

# Changed accounts list
accounts=()

for tag in "${tags[@]}"; do
    # ??? , but it works :)
    tag_name=$(eval echo \${${tag}[0]})
    tag_args=$(eval echo \${${tag}[1]})

    files=($(notmuch search --output=files --format=text -- "tag:${tag_name}"))

    handler="${tag_name}_handler"
    if [[ ! $(type -t "${handler}") == "function" ]]; then
        unset handler
    fi

    if [[ ${#files[@]} > 0 ]]; then
        # Parse affected accounts/channels and move to Trash
        for file in "${files[@]}"; do
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

            # Call tag handler function if provided
            [[ -v handler ]] && ${handler} "${file}" "${account}" "${channel}"
        done

        notmuch tag ${tag_args} -- "tag:${tag_name}"
    fi
done

# Sync changed accounts/channels
for (( i=0; i<${#accounts[@]}; i++ )); do
    echo easymail sync --push ${accounts[${i}]} ${channels[${i}]}
    easymail sync --push ${accounts[${i}]} ${channels[${i}]}
done
