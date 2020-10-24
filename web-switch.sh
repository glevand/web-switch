#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} - ETPW-622B/UIS-622B web-switch control." >&2
	echo "Usage: ${script_name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -h --help    - Show this help and exit." >&2
	echo "  -v --verbose - Verbose execution." >&2
	echo "  -c --config  - Configuration file. Default: '${config_file}'." >&2
	echo "  -t --target  - Target outlet {${known_targets}}. Default: '${target}'." >&2
	echo "  -a --action  - Action {${known_actions}}. Default: '${action}'." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="hvc:t:a:"
	local long_opts="help,verbose,config:,target:,action:"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			set -x
			#verbose=1
			shift
			;;
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
		--)
			shift
			if [[ ${*} ]]; then
				set +o xtrace
				echo "${script_name}: ERROR: Got extra args: '${*}'" >&2
				usage
				exit 1
			fi
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

	set +x
	echo "${script_name}: Done : ${result}." >&2
}

#===============================================================================
export PS4='\[\033[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}): \[\033[0;37m\]'
script_name="${0##*/}"

SCRIPTS_TOP="${SCRIPTS_TOP:-$(cd "${BASH_SOURCE%/*}" && pwd)}"

trap "on_exit 'failed'" EXIT
set -e
set -o pipefail

process_opts "${@}"

known_targets="uis 1 2 all"
known_actions="off on toggle reset status"

target="${target:-all}"
action="${action:-status}"
config_file="${config_file:-${SCRIPTS_TOP}/web-switch.conf}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

config_file="$(realpath "${config_file}")"

if [[ ! -f "${config_file}" ]]; then
	echo "${script_name}: ERROR: File not found --config: '${config_file}'" >&2
	usage
	exit 1
fi

source "${config_file}"

unset not_found
for v in "switch_name" "switch_user" "switch_passwd"; do
	if [[ -z "${!v}" || "${!v}" == "**unknown**" ]]; then
		echo "${script_name}: ERROR: No '${v}' setting found in config file: '${config_file}'" >&2
		not_found=1
	fi
done
if [[ ${not_found} ]]; then
	exit 1
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
	;;
on)
	cmd_control="control=1"
	;;
toggle)
	cmd_control="control=2"
	;;
reset)
	cmd_control="control=3"
	;;
status)
	echo "${script_name}: ERROR: TODO: '${action}'" >&2
	usage
	exit 1
	;;
*)
	echo "${script_name}: ERROR: Unknown action: '${action}'" >&2
	usage
	exit 1
	;;
esac

cmd_action="${cmd_action:-${cmd_target}&${cmd_control}}"

http_url="${http_url:-http://${switch_name}/cgi-bin/control2.cgi?user=${switch_user}&passwd=${switch_passwd}&${cmd_action}}"

echo "URL = '${http_url}'"

# http test:
# nc -kld -p 9000
# switch_name="http://localhost:9000"

# Target: “/cgi-bin/control.cgi?target=1&control=3”
# Target: “/xml/outlet_status.xml”

# "GET" <target> "HTTP/1.1"CRLF
# "Host:" <host ip>CRLF
# "Keep-Alive: 300"CRLF
# "Connection: keep-alive"CRLF
# "Authorization:Base" <auth>CRLFCRLF
# ;auth:encoded account(admin:1234) with base-64

curl="${curl:-curl}"

# FIXME: Get error: /login.asp?error=1

auth_p="${switch_user}:$(echo -n "${switch_passwd}" | base64)"
auth_up="$(echo -n "${switch_user}:${switch_passwd}" | base64)"

#auth="${auth_p}"
auth="${auth_up}"

curl_cmd=" \
 -X 'GET /cgi-bin/control.cgi?${cmd_action}' \
 -H 'Keep-Alive: 300' \
 -H 'Connection: keep-alive' \
 -H 'Authorization:Base ${auth}' \
 -H '' \
"

eval "${curl} -v ${curl_cmd} ${switch_name}"

trap "on_exit 'Success'" EXIT
exit 0
