_INDENT_SIZE=2
_INDENT_STACK=("0")
_DISABLE_INDENT=0

usage() {
    cat >&2 <<HEREDOC
  Usage: ${THIS_NAME} [[-v..|-q] [-n] [-b] [-f] [-o] [-x] [-y <0|1>] [-c <config file/path>] [-s <path-to-sets>] [-d <datetime(YYYY-MM-DD HH:MM:SS)>] [-l <datetime(YYYY-MM-DD HH:MM:SS)>] [-t <backup path>] [-j <jobs>] [set1..n] | -h ]
    -v: Increase verbosity
    -q: Quiet - overrides verbosity (no output except in case of error)
    -n: Dry run
    -t: Path to store backups
    -b: Force timestamp even if '-d' / '-f' or '-l' is set (normally automatically on every global full backup)
    -f: Force full save
    -o: Override existing backup directory
    -x: Dont use default config
    -y: Split 0 or 1
    -c: Use config file <file|path>
    -s: Path for sets
    -d: Override datetime of backup
    -l: Override last full date of backup
    -j: Max parallel jobs
    -h: Show Usage
    set1..n: Sets to save
HEREDOC
    exit 1
}

error() {
    echo >&2 "ERROR: ${1}"
}

msg() {
    local args=("$_VERBOSITY_MSG" "$@")
    _log "${args[@]}"
}
msgLine() {
    _logLine "$_VERBOSITY_MSG" "$1"
}

info() {
    local args=("$_VERBOSITY_INFO" "$@")
    _log "${args[@]}"
}
infoLine() {
    _logLine "$_VERBOSITY_INFO" "$1"
}

notice() {
    local args=("$_VERBOSITY_NOTICE" "$@")
    _log "${args[@]}"
}
noticeLine() {
    _logLine "$_VERBOSITY_NOTICE" "$1"
}

debug() {
    local args=("$_VERBOSITY_DEBUG" "$@")
    _log "${args[@]}"
}
debugLine() {
    _logLine "$_VERBOSITY_DEBUG" "$1"
}

_logLine() {
    local verbosity
    local ch
    local lineStr
    local args
    verbosity="$1"
    ch=$2

    lineStr=$(line "$ch")
    args=("$verbosity" "$lineStr")

    _DISABLE_INDENT=1
    _log "${args[@]}"
    _DISABLE_INDENT=0
}

_log() {
    local verbosity
    local args
    local prefix
    local indent
    verbosity="$1"
    shift

    #check max verbosity
    test "$verbosity" -gt "$_VERBOSITY_MAX" && verbosity=$_VERBOSITY_MAX

    # check min verbosity
    test "$verbosity" -gt "${VERBOSITY}" && return

    case "$verbosity" in
    "${_VERBOSITY_MSG}")
        prefix="MSG"
        ;;
    "${_VERBOSITY_INFO}")
        prefix="INFO"
        ;;
    "${_VERBOSITY_NOTICE}")
        prefix="NOTICE"
        ;;
    "${_VERBOSITY_DEBUG}")
        prefix="DEBUG"
        ;;
    *)
        prefix="UNKNOWN"
        ;;
    esac

    indents=""
    test "${_DISABLE_INDENT}" -eq 0 && indent="$(getIndents)"

    args=("$prefix" "${indent}$@")
    _doLog "${args[@]}"
}

_doLog() {
    local prefix
    prefix="$(printf '%-8s' "[$1]")"
    shift

    args=("$prefix" "$@")
    echo >&2 "${args[@]}"
}

mailLogLine() {
    local lineStr
    lineStr=$(line "*")
    #    _DISABLE_INDENT=1
    #    mailLogLn "$lineStr"
    #    _DISABLE_INDENT=0
    _mailLog 1 0 "$lineStr"
}

mailLog() {
    local args indents

    args=("$@")

    indents=""
    test "${_DISABLE_INDENT}" -eq 0 && indents="$(getIndents)"
    #    args=( "$indents" "$@")
    #    args[0]="$(printf '%s%s' "$indents" "${args[0]}")"
    #    echo "_DISABLE_INDENT: $_DISABLE_INDENT"
    args[0]="${indents}${args[0]}"

    _mailLog 0 1 "${args[@]}"
    #    printf '%s' "$@" # >&2
}

mailLogAppend() {
    _mailLog 0 0 "$@"
}

mailLogLn() {
    #    mailLog >&2 "$@"
    mailLog "$@"
    mailLogEnd ""
}
mailLogStart() {
    local args
    args=("$@" " ... ")
    mailLog "${args[@]}"
}
mailLogEndOk() {
    mailLogEnd "OK"
}

mailLogEnd() {
    _mailLog 1 0 "$(printf '%s\n' "$@")" # 2>&1
}
_mailLog() {
    local ln star prefix args
    ln="$1"
    star="$2"
    shift 2
    args=("$@")

    #    test "$star" -eq 1 && prefix='* '
    test "$star" -eq 1 && args[0]="* ${args[0]}"

    #    echo "aaaa"
    #    printf '"%s"\n' "${args[@]}"
    #    echo "bbbb"
    if [ "$ln" -eq 0 ]; then
        echo -n "${args[@]}"
        return
    fi

    echo "${args[@]}"

}

_createTmp() {
    local prefix s res dir realPrefix
    prefix="$1"
    dir="$(convertBool "$2" "0")"
    if [ -n "$prefix" ]; then
        s="$(uname -s)"
        if [ "$s" = "Darwin" ]; then
            realPrefix="$prefix"
        else
            realPrefix="${prefix}.XXXXXXX"
        fi
        if testBool "$dir"; then
            res="$(mktemp -t "$realPrefix" -d)"
        else
            res="$(mktemp -t "$realPrefix")"
        fi
    else
        if testBool "$dir"; then
            res="$(mktemp -d)"
        else
            res="$(mktemp)"
        fi
    fi
    printf '%s' "$res"
}

getIndentsLen() {
    local len
    len="${#_INDENT_STACK[@]}"

    if [ "${len}" -eq 0 ]; then
        echo -n "0"
        return
    fi

    echo -n "${_INDENT_STACK[$((len - 1))]}"
}

getIndents() {
    local indents
    indents="$(getIndentsLen)"
    test "$indents" -eq 0 && return
    # shellcheck disable=SC2183
    printf '%*s' "${indents}"
}

pushIndents() {
    local curIndent
    curIndent=$(getIndentsLen)
    _INDENT_STACK+=("$((curIndent + _INDENT_SIZE))")
}

popIndents() {
    local len newLen
    len="${#_INDENT_STACK[@]}"

    test "$len" -lt 1 && return

    newLen=$((len - 1))

    _INDENT_STACK=("${_INDENT_STACK[@]:0:$newLen}")
}

line() {
    local ch="${1:-=}"
    # shellcheck disable=SC2183
    printf '%*s\n' "${LINE_LENGTH}" | tr ' ' "$ch"
}

exitWithError() {
    local args
    args=("ERROR" "$@")
    _doLog >&2 "${args[@]}"
    exit 1
}

resolveLink() {
    local source="$1"
    local target
    local rc
    if [ -h "${source}" ]; then
        target="$(readlink "${source}")"
        rc=$?
        if [ $rc != 0 ]; then
            error "Error resolving link '${source}'"
            return $rc
        fi
        resolveLink "${target}" && return 0
        return 1
    fi

    if [ ! -e "${source}" ]; then
        error "Error resolving link '${source}', file does not exist!"
        return 1
    fi

    echo "${source}"
    return 0
}

initConfigFiles() {
    _CONFIG_FILES+=("${BASE_PATH}/conf/global.conf")
    _CONFIG_FILES+=("/etc/save_local.conf")
    _CONFIG_FILES+=("/etc/save_local/save_local.conf")
}

parseDate() {
    local dateStr
    local format
    dateStr="$1"
    format="${2:-"%Y-%m-%d %H:%M:%S"}"

    date --date "$dateStr" "+${format}" 2>/dev/null || date -j -f "${format}" "$dateStr" "+${format}" 2>/dev/null ||
        exitWithError "Wrong date string '$dateStr'"
}

_toFileDate() {
    local dateStr
    dateStr="$1"
    if [ "$(uname -s)" = "Darwin" ]; then
        date -j -f '%Y-%m-%d %H:%M:%S' "$dateStr" "+%Y-%m-%d_%H-%M-%S"
        return
    fi

    date --date "$dateStr" "+%Y-%m-%d_%H-%M-%S"
}

_checkRequiredOption() {
    local arg value
    arg="$1"
    value="$2"

    if [ -z "${value}" -o "${value:0:1}" = "-" ]; then
        exitWithError "Option '${arg}' requires a value"
    fi
}

_isNumber() {
    local value re
    value="$1"
    re='^([1-9][0-9]*|[0-9])$'
    if ! [[ $value =~ $re ]]; then
        return 1
    fi
    return 0
}

readOpt() {
    local tmpVal
    while getopts "hxvqnfboc:d:l:s:y:t:j:" o; do
        case "${o}" in
        x)
            _CMD_NO_DEFAULT_CONFIG=1
            ;;
        f)
            _CMD_FORCE_FULL=1
            _NO_FULL_TIMESTAMP=1
            _NO_FULL_TIMESTAMP_REASONS+=( "Full save is forced" )
            ;;
        b)
            _CMD_FORCE_FULL_TIMESTAMP=1
            ;;
        o)
            _CMD_OVERRIDE_EXISTING_BACKUPS=1
            ;;
        y)
            _checkRequiredOption "-y" "${OPTARG}"
            _CMD_SPLIT="$(convertBool "${OPTARG}")"
            ;;
        c)
            _checkRequiredOption "-c" "${OPTARG}"
            _CMD_CONFIG_FILE=${OPTARG}
            ;;
        d)
            _checkRequiredOption "-d" "${OPTARG}"
            tmpVal=${OPTARG}
            _CMD_DATETIME="$(parseDate "${tmpVal}")" || exitWithError "Wrong date format for '-d'"
            _NO_FULL_TIMESTAMP=1
            _NO_FULL_TIMESTAMP_REASONS+=( "Option '-d' set" )
            ;;
        l)
            _checkRequiredOption "-l" "${OPTARG}"
            tmpVal=${OPTARG}
            _CMD_LASTFULLDATE="$(parseDate "${tmpVal}")" || exitWithError "Wrong date format for '-l'"
            _NO_FULL_TIMESTAMP=1
            _NO_FULL_TIMESTAMP_REASONS+=( "Option '-l' set" )
            ;;
        t)
            _checkRequiredOption "-t" "${OPTARG}"
            _CMD_SAVE_DIR="${OPTARG}"
            ;;
        s)
            _checkRequiredOption "-s" "${OPTARG}"
            _CMD_SETS_PATH=${OPTARG}
            ;;
        v)
            test -z "${_CMD_VERBOSITY}" && _CMD_VERBOSITY="$_VERBOSITY_DEFAULT"
            _CMD_VERBOSITY=$((_CMD_VERBOSITY + 1))
            ;;
        q)
            _CMD_QUIET=1
            ;;
        n)
            _DRY_RUN=1
            ;;
        j)
            _checkRequiredOption "-j" "${OPTARG}"
            _isNumber "${OPTARG}" || exitWithError "Max jobs must be an integer >= 0"
            _CMD_MAX_JOBS="${OPTARG}"
            ;;
        *)
            usage
            ;;
        esac
    done
    shift $((OPTIND - 1))
    _CMD_SETS=("$@")
    #    echo "${#CMD_SETS[@]}"
}

_testBool() {
    local raw
    raw="$(echo "${1}" | tr '[:upper:]' '[:lower:]')"

    test "$raw" = "1" -o "$raw" = "y" -o "$raw" = "yes" -o "$raw" = "true" && return 0
    return 1
}

testBool() {
    local default
    local arg
    default="${2:-0}"
    arg="${1:-${default}}"
    _testBool "${arg}" && return 0
    return 1
}

convertBool() {
    local default
    local arg
    default="${2:-0}"
    arg="${1:-${default}}"
    _testBool "${arg}" && {
        echo -n '1'
        return 0
    }
    echo -n '0'
    return 1
}

includeConfigFiles() {
    local includedFiles=()

    local config_file

    local rc

    info "$(line)"
    info "Including config files ..."

    for f in "${_CONFIG_FILES[@]}"; do
        test -e "$f" || continue

        config_file="$(resolveLink "$f")"
        rc=$?
        test $rc -eq 0 || continue
        if [ -d "${config_file}" ]; then
            config_file="${config_file}/save_local.conf"
            test -e "${config_file}" || continue
            config_file="$(resolveLink "${config_file}")"
        fi

        fp="$(realpath "${config_file}" 2>/dev/null)"
        rc=$?
        test $rc -ne 0 && continue

        # shellcheck disable=SC2199
        # shellcheck disable=SC2076
        [[ " ${includedFiles[@]} " =~ " ${fp} " ]] && continue
        includedFiles+=("$fp")
        test -r "${fp}" || continue
        info "- '${fp}'"
        # shellcheck disable=SC1090
        . "${fp}"
    done

    info "$(line "-")"
    info ""
    #    echo "${includedFiles[@]}"

    #    [[ " ${branches[@]} " =~ " ${value} " ]] && echo "YES" || echo "NO";
}

_applyConfigFiles() {
    local config_file
    local rc
    if testBool "${_CMD_NO_DEFAULT_CONFIG}" n; then
        _CONFIG_FILES=()
        info "Do not include default config files"
    fi

    if [ -n "${_CMD_CONFIG_FILE}" ]; then
        config_file="$(resolveLink "${_CMD_CONFIG_FILE}")"
        rc=$?
        test $rc -eq 0 || exitWithError "Error resolving link '${_CMD_CONFIG_FILE}'"
        if [ -d "${config_file}" ]; then
            config_file="${config_file}/save_local.conf"
            config_file="$(resolveLink "${config_file}")"
            rc=$?
            test $rc -eq 0 || exitWithError "Error resolving link '${config_file}'"
        fi

        if [ ! -r "${config_file}" ]; then
            exitWithError "Config file '${config_file}' is not readable"
        fi
        _CONFIG_FILES+=("${config_file}")
    fi

    includeConfigFiles
}

_applyVerbosity() {
    test -n "${_CMD_VERBOSITY}" -a -n "${_CMD_QUIET}" && exitWithError "You can not set -q -v flags at the same time"

    if [ -n "${_CMD_QUIET}" ]; then
        VERBOSITY="${_VERBOSITY_QUIET}"
        return
    fi

    test -z "${_CMD_VERBOSITY}" && return

    VERBOSITY="${_CMD_VERBOSITY}"
}

_applyDryRun() {
    test "${_DRY_RUN}" -eq 0 && return
    msgLine
    msg "DRY RUN ENABLED"
    msgLine
}

_applySetsPath() {
    local c
    local idx
    info "$(line)"
    if [ -n "${_CMD_SETS_PATH}" ]; then
        info "Checking sets path '${_CMD_SETS_PATH}' ..."
        c="$(resolveLink "${_CMD_SETS_PATH}" 2>/dev/null)"
        test -z "$c" && exitWithError "Sets path '${_CMD_SETS_PATH}' does not exist"

        test -d "$c" || exitWithError "Sets path '${c}' is not a directory"

        c="$(realpath "${c}")"
        test -z "$c" && exitWithError "Could not get realpath for '$c'"

        info "-> using path '$c' ..."
        SETS_PATH="${c}"
        info "$(line "-")"
        info ""
        return
    fi

    info "Determining sets path ..."
    if [ -z "${SETS_PATH}" ]; then
        for ((idx = ${#_CONFIG_FILES[@]} - 1; idx >= 0; idx--)); do
            c="$(dirname "${_CONFIG_FILES[idx]}")/set"
            info "- checking path '$c' ..."

            if [ -e "${c}" ]; then
                c="$(resolveLink "$c")"
                test -z "$c" && continue
                if [ -d "$c" ]; then
                    SETS_PATH="$c"
                    info "-> using path '$c' ..."
                    break
                fi
            fi
        done
    fi

    test -z "${SETS_PATH}" && exitWithError "Could not determine sets path"

    info "$(line "-")"
    info ""
}

_applySets() {
    local sets=()
    local setNames=()
    local s
    local f
    local tf
    if [ "${#_CMD_SETS[@]}" -gt 0 ]; then
        SETS=("${_CMD_SETS[@]}")
    fi

    test "${#SETS[@]}" -lt 1 && exitWithError "No sets to backup set"

    info "$(line)"
    info "Checking sets ..."
    for s in "${SETS[@]}"; do
        info "- '$s' ..."

        f="${SETS_PATH}/$s.ini"

        test -e "$f" || exitWithError "     '${f}' does not exist"
        test -r "$f" || exitWithError "     '${f}' is not readable"

        tf="$(resolveLink "$f" 2>/dev/null)"
        test -z "$tf" && exitWithError "     Could not resolve link for '${f}'"

        f="$(realpath "$tf" 2>/dev/null)"
        test -z "$f" && exitWithError "     Could not get realpath for '${tf}'"

        # shellcheck disable=SC2199
        # shellcheck disable=SC2076
        if [[ " ${sets[@]} " =~ " ${f} " ]]; then
            info "  -> duplicate set ignored"
            continue
        fi

        sets+=("$f")
        setNames+=("$s")
    done

    SETS=("${sets[@]}")

    info "Backup sets: ${setNames[*]}"
    info "$(line "-")"
    info ""
}

_expandPath() {
    local path expandedPath
    path="$1"
    # check for absolute path
    if [ "${path:0:1}" = "/" ]; then
        echo -n "$path"
        return 0
    fi
    expandedPath="$(realpath "$path")"
    if [ -z "${expandedPath}" ]; then
        error "Path '$path' could not be resolved"
        return 1
    fi
    echo -n "$expandedPath"
    return 0
}

_handleBackupDef() {
    local path exclude enabled force_full
    local names
    local args
    local idx
    local def
    local expandedPath excludedPaths e tmpPath expandedExclude

    path="$1"
    exclude="$2"
    enabled="$(convertBool "$3" "1")"
    force_full="$(convertBool "$4" "0")"
    debug "Expanding path '${path}' ..."
    expandedPath="$(_expandPath "$path")"
    test -z "$expandedPath" && exitWithError "Path '$path' could not be resolved"
    path="$expandedPath"

    excludedPaths=()
    if [ -n "$exclude" ]; then
        IFS=':' read -r -a excludedPaths <<<"$exclude"
    fi
    expandedExclude=""
    for e in "${excludedPaths[@]}"; do
        tmpPath="$(_expandPath "$e" 2> /dev/null )"
        if [ -z "$tmpPath" ]; then
            # if it could not be expanded keep it as it is
            tmpPath="$e"
        fi
        if [ -z "$expandedExclude" ]; then
            expandedExclude="$tmpPath"
        else
            expandedExclude="${expandedExclude}:${tmpPath}"
        fi
    done
    exclude="$expandedExclude"

    names=("path" "exclude" "enabled" "force_full")
    args=("$path" "$exclude" "$enabled" "$force_full")


    def=""
    for ((idx = 0; idx < ${#names[@]}; idx++)); do
        def="$def$(printf '%s="%s";' "${names[idx]}" "${args[idx]}")"
        info " - $(printf '%s="%s"' "${names[idx]}" "${args[idx]}")"
    done

    _BACKUP_DEFS+=("$def")

}

parseIniFile() {
    local iniFile="$1"
    local tmpSectionName=""
    local sectionName=""
    local n
    # shellcheck disable=SC2034
    local path exclude enabled force_full
    while read -r l; do
        #        echo "$l"
        if [[ "$l" =~ ^\[(.*)\]$ ]]; then
            tmpSectionName="${BASH_REMATCH[1]}"
            # shellcheck disable=SC2199
            # shellcheck disable=SC2076
            [[ " ${_BACKUP_NAMES[@]} " =~ " ${tmpSectionName} " ]] && exitWithError "Duplicate section '$tmpSectionName'"
            test -n "$sectionName" && _handleBackupDef "$path" "$exclude" "$enabled" "$force_full"
            infoLine '-'
            info "Start Section '$tmpSectionName' ..."
            infoLine '-'
            sectionName="$tmpSectionName"
            _BACKUP_NAMES+=("$sectionName")
            exclude=""
            enabled="1"
            force_full="0"
            continue
        fi

        n="$(echo "$l" | cut -f1 -d'=')"
        if [[ ! "$n" =~ ^(path|exclude|enabled|force_full)$ ]]; then
            exitWithError "Error parsing '$iniFile': Key '$n' is not allowed"
        fi

        test -z "$sectionName" && exitWithError "Error parsing '$iniFile': Key '$n' is not in section"

        eval "$l"


    done < <(grep -Ev '^\s*([#;].*|\s*)$' "$f" | $SED_BIN -E 's/(^\s+|\s+$|\s*(=)\s*)/\2/g' | $SED_BIN -E 's/="?([^"]*?)"?$/="\1"/')

    test -n "$sectionName" && _handleBackupDef "$path" "$exclude" "$enabled" "$force_full"

}

_applyGlobalOption() {
    local label varName value overriddenValue msg type
    label="$1"
    if [ "$#" -gt 3 ]; then
        shift
    fi
    varName="$1"
    value="$2"
    overriddenValue="$3"
    msg="${label}: '${value}'"
    type="notice"
    if [ -n "$overriddenValue" ]; then
        msg="$msg - overridden by '${overriddenValue}'"
        eval "${varName}=\"$overriddenValue\""
        type="info"
    fi
    $type "- $msg"
}

_getLastFullDate() {
    local tsFile
    local tmpDate parsedDate
    pushIndents
    tsFile="${SAVE_DIR}/.lastBackup"
    if [ -r "${tsFile}" ]; then
        debug "Reading from '${tsFile}' ..."
        tmpDate="$(cat "${tsFile}")"
        if [ -z "$tmpDate" ]; then
            msg "Could not read date from '${tsFile}'"
        else
            parsedDate="$(parseDate "$tmpDate")"
            if [ -z "${parsedDate}" ]; then
                msg "Could not parse last full date '${tmpDate}' from '$tsFile'"
            else
                debug "Got last full date '$parsedDate' from '$tsFile' ..."
                _LASTFULLDATE="$parsedDate"
            fi
        fi
    else
        debug "'${tsFile}' does not exist ..."
    fi
    popIndents
}

_isFullSaveTimestampRequired() {
    local reasons rc
    notice "Checking if full save time stamp has to be set ..."
    pushIndents
    if ! testBool "${_FULL}"; then
        notice "NO: This is not a full backup"
        rc=1
    elif testBool "${_NO_FULL_TIMESTAMP}"; then
        reasons="$(printf '%s, ' "${_NO_FULL_TIMESTAMP_REASONS[@]}" | $SED_BIN -r 's/\, $//g')"
        if testBool "${_CMD_FORCE_FULL_TIMESTAMP}"; then
            notice "YES: Forced by '-b' (overrides: ${reasons})"
            rc=0
        else
            notice "NO: ${reasons}"
            rc=1
        fi
    elif [ "$RC" -gt 0 ]; then
        rc=1
        notice "NO: An error occurred"
    else
        rc=0
        notice "YES: full backup"
    fi
    popIndents
    return $rc
}

_setLastFullDate() {
    local tsFile

    _isFullSaveTimestampRequired || return

    tsFile="${SAVE_DIR}/.lastBackup"
    debug "Creating last backup file '$tsFile'"

    if [ "${_DRY_RUN}" -eq 1 ]; then
        msg "DRY RUN: Would create '$tsFile' ..."
        return
    fi
    test -z "${SAVE_DIR}" && exitWithError "Backup directory '${SAVE_DIR}' does not exist"
    printf '%s' "${BACKUP_DATETIME}" >"${tsFile}" || exitWithError "Could not create '$tsFile'"
}

_applySaveDir() {
    local realpath
    info "Checking save dir '$SAVE_DIR' ..."
    test -z "${SAVE_DIR}" && exitWithError "Save dir not set"
    realpath="$(realpath "$SAVE_DIR" 2>/dev/null)"
    if [ -n "$realpath" ]; then
        info "Resolving '${SAVE_DIR}' to '$realpath'"
        test "$realpath" = "/" && exitWithError "Could not save to '/'"
        test -d "$realpath" || exitWithError "Target directory '$realpath' is not a directory"
        SAVE_DIR="$realpath"
    else
        info "Creating '${SAVE_DIR}' in '$PWD' ..."
        if [ "${_DRY_RUN}" -eq 1 ]; then
            msg "DRY RUN: Would create '${SAVE_DIR}' ..."
        else
            mkdir -p "${SAVE_DIR}" || exitWithError "Could not create '${SAVE_DIR}'"
            info "Resolving '$SAVE_DIR' ..."
            realpath="$(realpath "$SAVE_DIR")"
            test -z "$realpath" && exitWithError "Could not resolve '$SAVE_DIR'"
            SAVE_DIR="$realpath"
        fi
    fi

    info "Saving to '$SAVE_DIR'"
}

_checkLockFile() {
    _GLOBAL_LOCKFILE="${SAVE_DIR}/.lock"
    test -e "${_GLOBAL_LOCKFILE}" || return
    exitWithError "Lock file '${_GLOBAL_LOCKFILE}' exists - aborting ..."
}

_createLockFile() {
    info "Creating lockfile '${_GLOBAL_LOCKFILE}' ..."
    test -z "${_GLOBAL_LOCKFILE}" && exitWithError "Variable '_GLOBAL_LOCKFILE' not set - aborting"
    if [ "${_DRY_RUN}" -eq 1 ]; then
        msg "DRY RUN: Would create '${_GLOBAL_LOCKFILE}' ..."
    else
        touch "${_GLOBAL_LOCKFILE}" || exitWithError "Could not create lockfile '${_GLOBAL_LOCKFILE}' ..."
    fi
}

_removeLockFile() {
    info "Removing lockfile '${_GLOBAL_LOCKFILE}' ..."
    if [ "${_DRY_RUN}" -eq 1 ]; then
        msg "DRY RUN: Would remove '${_GLOBAL_LOCKFILE}' ..."
    else
        test -z "${_GLOBAL_LOCKFILE}" && exitWithError "Variable '_GLOBAL_LOCKFILE' not set - aborting"
        rm -f "${_GLOBAL_LOCKFILE}" "${_GLOBAL_LOCKFILE}" || exitWithError "Could not create lockfile '${_GLOBAL_LOCKFILE}' ..."
    fi
}

_applyFull() {
    local fullDays backupDay dr d
    info "Checking for full save ..."
    # shellcheck disable=SC2153
    if [ "${FORCE_FULL}" -eq 1 ]; then
        info "Full backup forced ..."
        _FULL=1
        return
    fi

    if [ "${_LASTFULLDATE}" = "never" ]; then
        info "Last full date is 'never' - full save required"
        _FULL=1
        return
    fi

    # check if we have download day

    # shellcheck disable=SC2219
    let backupDay=$(echo "${BACKUP_DATETIME:8:2}" | $SED_BIN 's/^0//g')

    IFS=',' read -r -a fullDays <<<"${FULL_DAYS}"

    while read -r dr; do
        # shellcheck disable=SC2219
        let d="$(echo "$dr" | $SED_BIN 's/^0//g')"
        if [ "$d" -eq "$backupDay" ]; then
            info "Backup day '$backupDay' is in FULL_DAYS '${FULL_DAYS}' - full save required ..."
            _FULL=1
            break
        fi

    done < <(printf '%s\n' "${fullDays[@]}")
    test "${_FULL}" -eq 0 && info "Backup day '$backupDay' is NOT in FULL_DAYS '${FULL_DAYS}' - full save NOT required ..."

}

_applyGlobalOptions() {
    local msg tmpVal
    infoLine
    info "Global options:"
    _applyGlobalOption "BACKUP_DATETIME" "${BACKUP_DATETIME}" "${_CMD_DATETIME}"
    _applyGlobalOption "SAVE_DIR" "${SAVE_DIR}" "${_CMD_SAVE_DIR}"
    _applyGlobalOption "FORCE_FULL" "${FORCE_FULL}" "${_CMD_FORCE_FULL}"
    _applyGlobalOption "SPLIT" "${SPLIT}" "${_CMD_SPLIT}"
    _applyGlobalOption "MAX_JOBS" "${MAX_JOBS}" "${_CMD_MAX_JOBS}"
    _applyGlobalOption "OVERRIDE_EXISTING_BACKUPS" "${OVERRIDE_EXISTING_BACKUPS}" "${_CMD_OVERRIDE_EXISTING_BACKUPS}"
    pushIndents
    _checkLockFile
    _applySaveDir
    popIndents
    if ! testBool "${FORCE_FULL}"; then
        _getLastFullDate
        _applyGlobalOption "LASTFULLDATE" "_LASTFULLDATE" "${_LASTFULLDATE}" "${_CMD_LASTFULLDATE}"
    fi

    pushIndents
    _applyFull
    popIndents
}

_parseIniFiles() {
    local f
    for f in "${SETS[@]}"; do
        infoLine "="
        info "Parsing '$f' ..."
        pushIndents
        parseIniFile "$f"
        popIndents
        #        break;
    done
}

applyCmdArgs() {
    _applyVerbosity
    _applyDryRun
    _applyConfigFiles
    _applySetsPath
    _applySets
    _parseIniFiles
    test "${#_BACKUP_NAMES[@]}" -gt 0 || exitWithError "No jobs defined"
    _applyGlobalOptions
}

_lock() {
    info "Locking ..."
    touch "${_JOB_FOLDER}/.lock"
}
_unlock() {
    info "Unlocking ..."
    rm -f "${_JOB_FOLDER}/.lock"
}
_isLocked() {
    test -e "${_JOB_FOLDER}/.lock"
}
_waitForUnlock() {
    while _isLocked; do
        info "Waiting for unlock ..."
        sleep 1
    done
}

_runJob() {
    local name def tarParams full startTime endTime targetPath excludedPaths t logLen
    local fullSaveName waitFileName errorInfo errorFile p len fullReason tarLog rc
    local path exclude enabled force_full size
    local PSA
    name="$1"
    def="$2"
    force_full=0
    eval "$def"
    full=0
    if [ "${force_full}" -eq 1 ]; then
        full=1
        fullReason="Force full for '$name' is set"
    elif [ "${FORCE_FULL}" -eq 1 ]; then
        full=1
        fullReason="Force full globally enabled"
    elif [ "${_LASTFULLDATE}" = "never" ]; then
        full=1
        fullReason="Last full date was 'never'"
    elif [ "${_FULL}" -eq 1 ]; then
        full=1
        fullReason="It's full save day"
    fi
#    targetPath="${SAVE_DIR}/${name}"
    targetPath="$(_getTargetPath "$full" "$name")"

    tarLog="${targetPath}/save.log"
    fullSaveName="${targetPath}/save.tar.bz2"
    tarParams=("${_DEFAULT_TAR_PARAMS[@]}")
    test "$full" -eq 0 && tarParams+=("--newer-mtime=${BACKUP_DATETIME}")
    tarParams+=("--exclude=${SAVE_DIR}")
    waitFileName="${targetPath}/wait"
    errorFile="${targetPath}/error"
    startTime="$(date "+%Y-%m-%d %H:%M:%S")"
    excludedPaths=()
    if [ -n "$exclude" ]; then
        IFS=':' read -r -a excludedPaths <<<"$exclude"
    fi
    for t in "${excludedPaths[@]}"; do
        tarParams+=("--exclude=${t}")
    done
    test "${SPLIT}" -eq 0 && tarParams=("--file=${fullSaveName}" "${tarParams[@]}" )

    tarParams+=( "${path}" )

    mailLogLine
    mailLogLn "Starting job '$name' at '${startTime}'"
    mailLogLine "-"
    mailLogLn "path: $path"
    mailLogLn "backup name: $(_getTargetBase "$full" "$name")"
    if [ "${#excludedPaths[@]}" -eq 0 ]; then
        mailLogLn "exclude: -"
    else
        mailLogLn "exclude:"
        pushIndents
        for t in "${excludedPaths[@]}"; do
            mailLogLn "- ${t}"
        done
        popIndents
    fi
    if [ "$full" -eq 1 ]; then
        mailLogLn "full: $(_getPrintableBool "$full") (${fullReason})"
    else
        mailLogLn "full: $(_getPrintableBool "$full")"
    fi
    test "${_DRY_RUN}" -eq 1 && mailLogLn "Dry Run: YES"
    mailLogLine "-"

    mailLogStart "Create target dir '$(_getTargetBase "$full" "$name")'"
    if [ "${_DRY_RUN}" -eq 1 ]; then
        rc=0
        if [ -d "${targetPath}" ]; then
            if testBool "$OVERRIDE_EXISTING_BACKUPS"; then
                mailLogEnd "DRY RUN: would recreate it"
            else
                mailLogEnd "DRY RUN: ERROR - target dir exists - aborting"
                rc=2
            fi
        else
            mailLogEnd "DRY RUN: Would create it"
        fi

        if [ "$rc" -eq 0 ]; then
            mailLogLn "DRY RUN: Would create wait file '${waitFileName}'"
            mailLogLn "DRY RUN: Would create '${tarLog}'"
            mailLogLn "DRY RUN: Would execute 'tar ${tarParams[0]}"
            pushIndents
            pushIndents
            l=$((${#tarParams[@]} - 2))
            for p in "${tarParams[@]:1:${l}}"; do
                mailLogLn "${p} \\"
            done
            if [ "${SPLIT}" -eq 1 ]; then
                mailLogLn "${tarParams[$((l + 1))]} | split -b ${SPLITSIZE} - \"${fullSaveName}.\""
            else
                mailLogLn "${tarParams[$((l + 1))]}"
            fi
            if [ ! -r "${path}" ]; then
                mailLogLn "DRY RUN: ERROR - Path to save '$path' is not readable"
                rc=2
            else
                rc=0
            fi
            popIndents
            popIndents
            test "$rc" -eq 0 && mailLogLn "DRY RUN: Would remove wait file '${waitFileName}'"
        fi
    else
        if [ -d "${targetPath}" ]; then
            if testBool "$OVERRIDE_EXISTING_BACKUPS"; then
                mailLogAppend "recreating ... "
                test -n "${targetPath}" || exitWithError "targetPath is empty - this should never happen"
                rm -rf "${targetPath}" || exitWithError "Error removing targetPath '${targetPath}'"
            else
                exitWithError "Target dir exists - aborting"
            fi
        fi
            mkdir -p "${targetPath}" || exitWithError "Could not create '${targetPath}'"
            mailLogEndOk

        mailLogStart "Creating wait file"
        echo "$$" >"${waitFileName}" || exitWithError "Could not create '${waitFileName}'"
        mailLogEndOk
        mailLogStart "Creating logFile file"
        touch "${tarLog}" || exitWithError "Could not create '${tarLog}'"
        mailLogEndOk

        mailLogStart "Backing up"

        if [ ! -r "${path}" ]; then
            mailLogEnd "ERROR: Path to save '$path' is not readable"
            echo "ERROR: Path to save '$path' is not readable" > "${tarLog}"
            rc=2
        elif [ "${SPLIT}" -eq 1 ]; then
            (
                tar "${tarParams[@]}" | split -b "${SPLITSIZE}" - "${fullSaveName}.";
                PSA=( "${PIPESTATUS[@]}" )

                # rc of split command
                test "${PSA[1]}" -gt 0 && exit 2
                # exit with tar rc
                exit "${PSA[0]}"

            ) > "${tarLog}" 2>&1

            rc=$?
            size="$(du -shc "${fullSaveName}".* | tail -n 1 | cut -f1)"
        else
#            echo tar "${tarParams[@]}" > "${tarLog}" 2>&1
#            tar -f "${fullSaveName}" "${tarParams[@]}" > "${tarLog}" 2>&1
            tar "${tarParams[@]}" > "${tarLog}" 2>&1
            rc=$?
            size="$(du -shc "${fullSaveName}" | tail -n 1 | cut -f1)"
        fi

        if [ "$rc" -eq 0 ]; then
            mailLogEndOk
        elif [ "$rc" -eq 1 ] && [ "$(uname -s)" = "Linux" ]; then
            # linux tar returns 1 if some files differs, only > 1 means an error
            rc=0
            mailLogEndOk
        else
            mailLogEnd "Error (Code: $rc)"
            logLen="$(wc -l "$tarLog" | $SED_BIN -r 's/^\s*([0-9]+).*$/\1/g')"
            pushIndents
            mailLog "Logfile:"
            if [ "$logLen" -gt  "${MAX_MAIL_LOG_LEN}" ]; then
                mailLogEnd " (full log file in backup folder)"
                mailLogLn "---"
                mailLogLn "..."
            else
                mailLogEnd ""
                mailLogLn "---"
            fi
            while read -r l; do
                mailLogLn "$l"
            done < <(tail -n "${MAX_MAIL_LOG_LEN}" "$tarLog" )
            mailLogLn "---"
        fi

        # keep wait file in case of error as indicator
        if [ "$rc" -ne 0 ]; then
            errorInfo="ERROR CODE ($rc) for '${name}' at $(date "+%Y-%m-%d %H:%M:%S")"
            mailLog "${errorInfo}"
            mailLogStart "Writing information to error file"
            echo "${errorInfo}" >>"${errorInfo}"
            mailLogEnd "DONE"
        fi

        # always remove mail file
        mailLogStart "Removing wait file"
        rm "${waitFileName}" && mailLogEndOk

        mailLogLn "Backup Size: ${size}"

    fi

    endTime="$(date "+%Y-%m-%d %H:%M:%S")"

    mailLogLine '-'
    mailLogLn "Finishing job '$name' at '${endTime}'"
    mailLogLine "-"

    test "$rc" -gt 0 && _setRC
}

runJob() {
    local logFile l job
    job="$1"

    logFile="${_JOB_FOLDER}/$job/log"
    cat /dev/null >"${logFile}"

    _runJob "$@" 2>&1 | while read -r l; do
        echo "$l" >>"${logFile}"
#        debug "$l"
    done

}

_appendLogFile() {
    local job msg logFile

    job="$1"
    msg="${2:-}"

    logFile="${_JOB_FOLDER}/$job/log"
    test -n "$msg" && printf '\n%s\n' "$msg" >>"$logFile"
    info "Appending '$logFile' to '${_LOG_FILE}' ..."
    cat "$logFile" >>"${_LOG_FILE}"
}

runBgJob() {
    local pidFile logFile rc job l
    job="$1"

    logFile="${_JOB_FOLDER}/$job/log"
    #    runJob "$@" >"${logFile}" 2>&1
    runJob "$@"
    rc=$?
    test "$rc" -gt 0 && RC=1

    _waitForUnlock
    _lock
    pidFile="${_JOB_FOLDER}/$job/pid"
    info "Removing pidFile '$pidFile'"
    rm -f "$pidFile"
    _appendLogFile "$job"
#    while read -r l; do
#        info "$l"
#    done < <(cat "$logFile")
    #    debug "Appending '$logFile' to '${_LOG_FILE}' ..."
    #    cat "$logFile" >>"${_LOG_FILE}"
    _unlock
}

startBgJob() {
    local pid job def defFile pidFile
    defFile="$1"
    job="$(basename "$(dirname "$defFile")")"

    #    defFile="${_JOB_FOLDER}/$job/open"
    pidFile="${_JOB_FOLDER}/$job/pid"
    def="$(cat "$defFile")"

    #    echo "defFile: $def"
    #    echo "job: $job"
    #    echo "def: $def"
    _waitForUnlock
    _lock
    info "Starting job '$job' with '$defFile'"
    runBgJob "$job" "$def" &
    pid=$!

    info "Creating pid file '$pidFile'"
    echo "${pid}" >"$pidFile"

    info "Removing open file '$defFile'"
    rm "$defFile"
    _unlock
}

_getNumberOfOpenJobs() {
    local res
    res="$(find "${_JOB_FOLDER}" -name 'open' | wc -l | tr -d ' ')"
    printf '%s' "$res"
}

startNextBgJob() {
    local f job def idx openJobs rc pattern

    # start all open jobs
    debug "Starting open jobs ..."
    while [ "$(_getNumberOfOpenJobs)" -gt 0 ]; do
        idx=0
        while read -r f; do
            _waitForUnlock
            #            echo "f: $f"
            idx=$((idx + 1))
            job="$(basename "$(dirname "$f")")"
            startBgJob "$f"
            test "$idx" -ge "${MAX_JOBS}" && break
        done < <(find "${_JOB_FOLDER}" -name 'open')
        sleep 2
    done

    # wait until there are no more jobs running
    debug "Searching for open processes "
    while true; do
        _waitForUnlock
        sync
        f="$(find "${_JOB_FOLDER}" -name 'pid' | head -n 1)"
        test -z "$f" && break
        sleep 2
    done

    #    while read -r f; do
    #        debug "Found pidFile '$f' ..."
    #        _waitForUnlock
    #        sync
    #        sleep 2
    #    done < <(find "${_JOB_FOLDER}" -name 'pid')

}

_killRunningJobs() {
    local pidFile p j
    msg "---- INTERRUPTED -------"

    while read -r pidFile; do
        p="$(cat "$pidFile")"
        j="$(basename "$(dirname "$pidFile")")"
        pushIndents
        msg "- Killing job '$j' with pid '$p' ... OK"
        popIndents
        _appendLogFile "$j" "---INTERRUPTED---"
        kill -9 "$p" 2>/dev/null
        rm -f "${pidFile}"
    done < <(find "${_JOB_FOLDER}" -name 'pid')

}

trap _killRunningJobs TERM INT ABRT

_getPrintableBool() {
    local value="$1"
    if testBool "$value"; then
        echo "YES"
    else
        echo "NO"
    fi
}

_prepareJobFolder() {
    local jobFolder
    jobFolder="$(_createTmp "save_local.jobs" 1)"
    _TMP_FILES+=("$_JOB_FOLDER")
    printf '%s' "$jobFolder"
}

_createJobConfigFolder() {
    local jobConfigFolder job def
    job="$1"
    def="$2"
    jobConfigFolder="${_JOB_FOLDER}/${job}"
    mkdir "$jobConfigFolder" || exitWithError "Could not create job config folder '$jobConfigFolder'"
}

_isEnabled() {
    local def
    local path exclude enabled force_full
    def="$1"
    eval "$def"
    testBool "$enabled" && return 0
    return 1
}

_initRC() {
    local rcFile
    rcFile="${SAVE_DIR}/.rc"
    if [ "${_DRY_RUN}" -eq 1 ]; then
        msg "DRY RUN: Would create '$rcFile'"
        return
    fi
    info "Creating '$rcFile' with '0'"
    printf '0' > "${rcFile}"
}
_setRC() {
    local rcFile
    rcFile="${SAVE_DIR}/.rc"
    test "${_DRY_RUN}" -eq 1 && return
    printf '1' > "${rcFile}"
}
_getRC() {
    local rcFile rc
    rcFile="${SAVE_DIR}/.rc"
    if [ "${_DRY_RUN}" -eq 1 ]; then
        msg "DRY RUN: Would read return code from '$rcFile', but return 0"
        return 0
    fi
    debug "Read return code from '$rcFile'"
    rc=$(($(cat "${rcFile}")))
    return $rc
}
_clearRC() {
    local rcFile
    rcFile="${SAVE_DIR}/.rc"
    if [ "${_DRY_RUN}" -eq 1 ]; then
        msg "DRY RUN: Would remove '$rcFile'"
        return
    fi
    debug "Removing '$rcFile'"
    rm -f "${rcFile}"
}

_getTargetPath() {
    printf '%s/%s' "${SAVE_DIR}" "$(_getTargetBase "$@")"
}

_getTargetBase() {
    local curDate sinceDate name full
    full="$1"
    name="$2"
    curDate="$(_toFileDate "${BACKUP_DATETIME}")"
    if [ "$full" -eq 1 ]; then
        printf '%s_full_%s' "$curDate" "$name"
    else
        sinceDate="$(_toFileDate "${_LASTFULLDATE}")"
        printf '%s_since_%s_%s' "$curDate" "$sinceDate" "$name"
    fi
}

startJobs() {
    local job def len jobConfigFolder idx endTime maxJobs p
    _OPEN_JOBS=("${_BACKUP_NAMES[@]}")
    _OPEN_DEFS=("${_BACKUP_DEFS[@]}")
    cat /dev/null >"${_LOG_FILE}"
    info "Starting jobs ..."
    _initRC
    _createLockFile
    (
        mailLogLine
        mailLogLn "$(printf 'Save to "%s"' "$SAVE_DIR")"
        mailLogLn "$(printf 'Last full save: %s' "$_LASTFULLDATE")"
        mailLogLn "$(printf 'Backup date: %s' "$BACKUP_DATETIME")"
        mailLogLn "$(printf 'Split: %s' "$(_getPrintableBool "$SPLIT")")"
        mailLogLn "$(printf 'Starting at: %s' "$_START_TIME")"
        mailLogLine
        mailLogLn "Default tar parameters:"
        pushIndents
        pushIndents
        for p in "${_DEFAULT_TAR_PARAMS[@]}"; do
            mailLogLn "'$p'"
        done
        popIndents
        popIndents
    ) | while read -r l; do
        echo "$l" >>"${_LOG_FILE}"
#        notice "$l"
    done

    maxJobs=${MAX_JOBS}
    test "$maxJobs" -gt "${#_OPEN_JOBS[@]}" && maxJobs="${#_OPEN_JOBS[@]}"

    if [ "${maxJobs}" -lt 2 ]; then
        debug "Run synchronously"
        _JOB_FOLDER="$(_prepareJobFolder)"
         test -z "${_JOB_FOLDER}" && exitWithError "Could not create job folder"
        while [ "${#_OPEN_JOBS[@]}" -gt 0 ]; do
            job="${_OPEN_JOBS[0]}"
            def="${_OPEN_DEFS[0]}"
            if _isEnabled "$def"; then
                _createJobConfigFolder "$job" "$def"
                runJob "${job}" "${def}"
                _appendLogFile "$job"
            else
                info "Ignoring disabled job '$job'"
            fi
            _OPEN_JOBS=("${_OPEN_JOBS[@]:1}")
            _OPEN_DEFS=("${_OPEN_DEFS[@]:1}")
        done
    else
        info "Starting background jobs ..."
        _JOB_FOLDER="$(_createTmp "save_local.jobs" 1)"
        _TMP_FILES+=("$_JOB_FOLDER")
        test -z "${_JOB_FOLDER}" && exitWithError "Could not create job folder"
        for ((idx = 0; idx < "${#_BACKUP_NAMES[@]}"; idx++)); do
            job="${_BACKUP_NAMES[idx]}"
            def="${_BACKUP_DEFS[idx]}"
            if _isEnabled "$def"; then
                jobConfigFolder="${_JOB_FOLDER}/${job}"
                mkdir "$jobConfigFolder" || exitWithError "Could not create job config folder '$jobConfigFolder'"
                printf '%s' "$def" >"$jobConfigFolder/open" || exitWithError "Could not write to '$jobConfigFolder/open'"
            else
                info "Ignoring disabled job '$job'"
            fi
        done
        startNextBgJob
    fi

    endTime="$(date "+%Y-%m-%d %H:%M:%S")"
    (
        mailLogLn "$(printf 'Completing backup at: %s' "'$endTime'")"
        mailLogLine
    ) | while read -r l; do
        echo "$l" >>"${_LOG_FILE}"
#        notice "$l"
    done

    RC=0
    _getRC || RC=1
    _clearRC

    _removeLockFile
    _setLastFullDate

}
