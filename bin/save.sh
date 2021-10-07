#!/usr/bin/env bash


THIS="$0"

THIS_NAME="$(basename "$0")"
THIS_PATH="$(dirname "$0")"
THIS_PID="$$"

REAL_THIS="${THIS}"
while [ -h "${REAL_THIS}" ]; do
    REAL_THIS="$(readlink "${REAL_THIS}")"
done
REAL_THIS="$(realpath "${REAL_THIS}")"

BASE_PATH="$(dirname "${REAL_THIS}")/.."
BASE_PATH="$(realpath "${BASE_PATH}")"


_VERBOSITY_QUIET=0
_VERBOSITY_MSG=1
_VERBOSITY_INFO=2
_VERBOSITY_NOTICE=3
_VERBOSITY_DEBUG=4
_VERBOSITY_MAX="${_VERBOSITY_DEBUG}"
_VERBOSITY_DEFAULT="${_VERBOSITY_MSG}"
_LASTFULLDATE="never"

VERBOSITY="${_VERBOSITY_DEFAULT}"
QUIET=0
SETS_PATH=
SETS=()
FORCE_FULL=0
_FULL=0
FULL_DAYS=1,7,13
BACKUP_DATETIME="$(date "+%Y-%m-%d %H:%M:%S")"
SAVE_DIR="/backup/save"
SPLIT=0
SPLITSIZE=4687798015
#SPLITSIZE=150
MAX_JOBS=3
MAX_MAIL_LOG_LEN=50
_DRY_RUN=0

_CONFIG_FILES=()
_CMD_FORCE_FULL=
_CMD_CONFIG_FILE=
_CMD_NO_DEFAULT_CONFIG=
_CMD_VERBOSITY=
_CMD_QUIET=
_CMD_SETS=()
_CMD_SETS_PATH=
_CMD_DATETIME=
_CMD_LASTFULLDATE=
_CMD_SAVE_DIR=
_CMD_SPLIT=
_CMD_MAX_JOBS=

LINE_LENGTH=78

_BACKUP_NAMES=()
_BACKUP_DEFS=()
_JOB_FOLDER=
_RUNNING_JOBS=()
_IS_CLEANING_JOB=0

_OPEN_JOBS=()
_OPEN_DEFS=()

_TMP_FILES=()
_LOG_FILE=
_START_TIME="$(date "+%Y-%m-%d %H:%M:%S")"
_GLOBAL_LOCKFILE=

_LOCKED=0
RC=0

SED_BIN="$(which gsed || which sed)"

# Standardparameter fuer Tar
#_DEFAULT_TAR_PARAMS=("-cvjpm" "--ignore-failed-read")
_DEFAULT_TAR_PARAMS=("-cvjpm")

#exclude trash and backups
_DEFAULT_TAR_PARAMS+=( "--exclude=lost+found" "--exclude=.AppleDouble" )
_DEFAULT_TAR_PARAMS+=( "--exclude=.AppleDesktop" "--exclude=.AppleDB" "--exclude=Temporary Items" )
_DEFAULT_TAR_PARAMS+=( "--exclude=Network Trash Folder"  "--exclude=.recycle --exclude=*~" )
_DEFAULT_TAR_PARAMS+=( "--exclude=.Trash-*" "--exclude=.cache" "--exclude={*.pid,*.sock,*.socket}")
_DEFAULT_TAR_PARAMS+=( "--exclude=dontsave")



_cleanUp() {
#    echo "CLEANING"
    local t
    for t in "${_TMP_FILES[@]}"; do
        rm -rf "$t"
    done
}
trap _cleanUp EXIT

error() {
  >&2 echo "ERROR: ${1}"
}

incLib() {
  local libPath
  local rc=$?
  test $rc -eq 0 || exit 1

  libPath="${BASE_PATH}/lib/lib.sh"
  if [ ! -f "${libPath}" ]; then
    error "Missing file '${libPath}'"
    exit 1
  fi
  # shellcheck disable=SC1090
  . "${libPath}"
}



incLib

test -z "${SED_BIN}" && exitWithError "Could not find gsed nor sed path"
test -z "${BASE_PATH}" && exitWithError "Could not determine BASE_PATH"

cd "${BASE_PATH}" || exitWithError "Could not change to directory '${BASE_PATH}'"

initConfigFiles


readOpt "$@"


applyCmdArgs

#_createTmp "affe"
_LOG_FILE="$(_createTmp "save_local.global_log")"
_TMP_FILES+=( "${_LOG_FILE}" )

startJobs

if [ "$RC" -eq 0 ]; then
    test "$_VERBOSITY_QUIET" -eq "${VERBOSITY}" && exit 0
fi

# output log
cat "${_LOG_FILE}"


test "$RC" -eq 0 || exitWithError "An error occurred"
exit 0
