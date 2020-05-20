#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - ETPW-622B/UIS-622B web-switch control." >&2
		echo "Usage: ${script_name} [flags]"
		echo 'Option flags:'
		echo "  -c --config  - Configuration file. Default: '${config_file}'."
		echo "  -t --target  - Target outlet {${known_targets}}. Default: '${target}'."
		echo "  -a --action  - Action {${known_actions}}. Default: '${action}'."
		echo "  -h --help    - Show this help and exit."
		echo "  -v --verbose - Verbose execution. Default: '${verbose}'."
		echo "  -g --debug   - Extra verbose execution. Default: '${debug}'."
		echo "  -d --dry-run - Dry run, don't send command to device."
		if [[ ${verbose} ]]; then
			echo 'Config:'
			echo "  switch_name     = '${switch_name:-** unknown **}'"
			echo "  switch_user     = '${switch_user:-** unknown **}'"
			echo "  switch_passwd   = '${switch_passwd:-** unknown **}'"
			echo "  connect_timeout = '${connect_timeout:-** unknown **}'"
		fi
		echo 'Info:'
		echo '  Project Home: https://github.com/glevand/web-switch'
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts='c:t:a:hvgd'
	local long_opts='config:,target:,action:,help,verbose,debug,dry-run'

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-c | --config)
			config_file="${2}"
			shift 2
			;;
		-t | --target)
			target="${2}"
			shift 2
			;;
		-a | --action)
			action="${2}"
			shift 2
			;;
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			verbose=1
			shift
			;;
		-g | --debug)
			verbose=1
			debug=1
			set -x
			shift
			;;
		-d | --dry-run)
			dry_run=1
			shift
			;;
		--)
			shift
			extra_args="${*}"
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}

	local sec="${SECONDS}"

	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec." >&2
}

on_err() {
	local f_name=${1}
	local line_no=${2}
	local err_no=${3}

	{
		echo "${script_name}: ERROR: function=${f_name}, line=${line_no}, result=${err_no}"
	} >&2

	exit "${err_no}"
}

print_result() {
	local result="${1}"

	local outlet_regex='<outlet_status>([01]),([01])</outlet_status>'
	local outlet_status_1='unknown'
	local outlet_status_2='unknown'

	if [[ "${result}" =~ ${outlet_regex} ]]; then
		outlet_status_1="${BASH_REMATCH[1]}"
		outlet_status_2="${BASH_REMATCH[2]}"
	else
		echo "${script_name}: ERROR: No outlet regex match '${result}'" >&2
	fi

	local uis_regex_1='<uis_fun>(.*)</uis_fun>'
	local uis_regex_2='<uis_status>(.*)</uis_status>'
	local uis_status='unknown'

	if [[ "${result}" =~ ${uis_regex_1} || "${result}" =~ ${uis_regex_2} ]]; then
		uis_status="${BASH_REMATCH[1]}"
	else
		echo "${script_name}: ERROR: No uis regex match '${result}'" >&2
	fi

	echo "${script_name}: Status outlet #1 = ${outlet_status_1}"
	echo "${script_name}: Status outlet #2 = ${outlet_status_2}"
	echo "${script_name}: Status uis       = ${uis_status}"
}

run_cmd() {
	local uri_path="${1}"
	local -n _run_cmd__result="${2}"

	_run_cmd__result=''

	local curl_extra=''
	if [[ ${verbose} ]]; then
		curl_extra='--verbose '
	fi

# 	local auth="$(echo -n "${switch_user}:${switch_passwd}" | base64)"
# 	local curl_cmd="${curl_extra}--silent 'http://${switch_name}/${uri_path}' \
# 	-H 'Keep-Alive: 300' \
# 	-H 'Connection: keep-alive' \
# 	-H 'Authorization:Base ${auth}' \
# 	-H '' \
# 	"

	local curl_cmd="${curl_extra}--silent --connect-timeout ${connect_timeout} 'http://${switch_name}/${uri_path}'"

	if [[ ${verbose} ]]; then
		echo "${script_name}: curl cmd = '${curl_cmd/${switch_passwd}/***}'."
		echo
	fi

	if [[ ${dry_run} ]]; then
		return
	fi

	local result
	local status=0

	result="$(eval "'${curl}' ${curl_cmd}")" || status="${?}"

	if [[ ${verbose} ]]; then
		echo
	fi

	case "${status}" in
	'0')
		:
		;;
	'7')
		echo "${script_name}: ERROR: curl failed with exit code '${status}'." >&2
		echo "${script_name}: ERROR: Failed to connect to host." >&2
		exit ${status}
		;;
	'28')
		echo "${script_name}: ERROR: curl failed with exit code '${status}'." >&2
		echo "${script_name}: ERROR: Connect timed out after ${connect_timeout} seconds." >&2
		exit ${status}
		;;

	*)
		echo "${script_name}: ERROR: curl failed with exit code '${status}'." >&2
		exit ${status}
		;;
	esac

	if [[ ${verbose} ]]; then
		echo "Switch reply:"
		echo "${result}"
		echo
	fi
	print_result "${result}"
	_run_cmd__result="${result}"
}

set_switch() {
	if [[ "${action}" == 'toggle' && "${target}" == 'all' ]]; then
		echo "${script_name}: ERROR: 'toggle all' not supported by device." >&2
		exit 1
	fi

	if [[ ${dry_run} ]]; then
		echo "${script_name}: Setting switch ${target} ${action} (DRY RUN)."
	else
		echo "${script_name}: Setting switch ${target} ${action}."
	fi

	local uri_path="cgi-bin/control2.cgi?user=${switch_user}&passwd=${switch_passwd}&${cmd_target}&${cmd_control}"
	local result
	
	run_cmd "${uri_path}" result
}

get_status() {
	if [[ ${dry_run} ]]; then
		echo "${script_name}: Reading switch status (DRY RUN)."
	else
		echo "${script_name}: Reading switch status."
	fi

	local uri_path='xml/outlet_status.xml'
	local result
	
	run_cmd "${uri_path}" result
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"

SECONDS=0
start_time="$(date +%Y.%m.%d-%H.%M.%S)"

real_source="$(realpath "${BASH_SOURCE}")"
SCRIPT_TOP="$(realpath "${SCRIPT_TOP:-${real_source%/*}}")"

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
trap 'on_err SIGUSR1 ? 3' SIGUSR1

set -eE
set -o pipefail
set -o nounset

known_targets="uis 1 2 all"
known_actions="off on toggle reset status"

config_file="${HOME}/web-switch.conf"
target='all'
action='status'
usage=''
verbose=''
debug=''
dry_run=''

curl="${curl:-curl}"

process_opts "${@}"

config_file="$(realpath "${config_file}")"

if [[ ! -f "${config_file}" ]]; then
	echo "${script_name}: ERROR: Config file not found: '${config_file}'." >&2
	usage
	exit 1
fi

source "${config_file}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if [[ ${extra_args} ]]; then
	set +o xtrace
	echo "${script_name}: ERROR: Got extra args: '${extra_args}'" >&2
	usage
	exit 1
fi

connect_timeout="${connect_timeout:-20}"

not_found=''

for var in "switch_name" "switch_user" "switch_passwd"; do
	if [[ ! ${!var} || "${!var}" == "**unknown**" ]]; then
		echo "${script_name}: ERROR: No '${var}' setting found in config file: '${config_file}'" >&2
		not_found=1
	fi
done

if [[ ${not_found} ]]; then
	exit 1
fi

if ! test -x "$(command -v "${curl}")"; then
	echo "${script_name}: ERROR: Please install '${curl}'." >&2
	result=1
fi

case "${target}" in
uis)
	cmd_target="target=0"
	;;
1)
	cmd_target="target=1"
	;;
2)
	cmd_target="target=2"
	;;
all)
	cmd_target="target=3"
	;;
*)
	echo "${script_name}: ERROR: Unknown target: '${target}'" >&2
	usage
	exit 1
	;;
esac

case "${action}" in
off)
	cmd_control="control=0"
	set_switch
	;;
on)
	cmd_control="control=1"
	set_switch
	;;
toggle)
	cmd_control="control=2"
	set_switch
	;;
reset)
	cmd_control="control=3"
	set_switch
	;;
status)
	cmd_control=''
	get_status
	;;
*)
	echo "${script_name}: ERROR: Unknown action: '${action}'" >&2
	usage
	exit 1
	;;
esac

trap "on_exit 'Success'" EXIT
exit 0
