#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)
# To terminate the script immediately after any non-zero exit status use:  set -e

# =========================
# Author:          Jon Zeolla (JZeolla, JonZeolla)
# Last update:     2016-12-09
# File Type:       Bash Script
# Version:         1.2
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a simple bash script to create a certificate signing request.
#
# Notes
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

function cleanup() {
    rm -f /tmp/random.data /tmp/openssl.cnf

    case "${1}" in
        error)
            exit 1
            ;;
        quit)
            exit 0
            ;;
        *)
            # no-op
            :
            ;;
    esac
}

function checkInput() {
    # Reset cleanInput
    cleanInput=""

    # Assume it isn't an IP
    isIP=0

    if [ -z "${CN}" ]; then
        # Require some sort of CN
        cleanInput="${CN}fail"
    fi

    ## Clean up the input
    sanitizeInput="${1//[!a-zA-Z0-9\.\-\*]/}"

    if [[ "${sanitizeInput}" == \** ]]; then
        # There is at least one asterisk and it is at the beginning.
        # If there is more than one, remove the second one to break checks later on
        cleanInput=$(sed 's/\*//2' <<< "${sanitizeInput}")
    elif [[ "${sanitizeInput}" != *\** && "${sanitizeInput}" != "" ]]; then
        # There is no asterisk
        cleanInput="${sanitizeInput}"

        # Check to see if it's an IP - IPv6 is not yet supported due to its detection complexity
        if [[ "${cleanInput}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            origIFS="${IFS}"
            IFS='.'
            ip=(${cleanInput})
            IFS="${origIFS}"
            if [[ "${ip[0]}" -le 255 && "${ip[1]}" -le 255 && "{ip[2]}" -le 255 && "${ip[3]}" -le 255 ]]; then
                isIP="1"
            fi
        fi
    else
        # The first asterisk was not at the beginning.  Don't set cleanInput
        :
    fi
}

# trap and call cleanup()
trap 'cleanup error' SIGINT SIGTERM SIGHUP

if [[ ! -w "${PWD}" || ! -w /tmp ]]; then
    echo -e "Please ensure you have the proper permissions to ${PWD} and /tmp"
    cleanup "error"
fi

cleanInput=""
isIP=0

echo -e "\nDon't forget to run this in the directory that you have your key\n"
echo "What should the CN be for the certificate?  Your current hostname is ${HOSTNAME}"
read -r CN
checkInput "${CN}"

until [[ "${CN}" == "${cleanInput}" && "${isIP}" == 0 ]]; do
    if [[ "${isIP}" != 0 ]]; then
        echo -e "\nPlease do not use an IP as the CN.  The CN you provided was ${CN}."
    elif [[ "${CN}" != "${cleanInput}" ]]; then
        echo -e "\nPlease formulate a valid CN.  The CN you provided was ${CN}."
    fi
    echo "What should the CN be for the certificate?"
    read -r CN
    checkInput ${CN}
done

if [[ -e /tmp/random.data || -e /tmp/openssl.cnf ]]; then
    cleanup
fi

echo "Generating random data..."
dd if=/dev/urandom of=/tmp/random.data bs=4096k count=1 2> /dev/null

if [[ ! -e "${CN}.key" ]]; then
    echo "Generating cert..."
    openssl genrsa -rand /tmp/random.data -out "${CN}.key" 4096
fi

echo "Configuring OpenSSL..."
echo "[req]
default_bits = 4096
prompt = no
distinguished_name = Subject_Name

[Subject_Name]
C  = US
ST = Pennsylvania
L  = Pittsburgh
O  = TODO
OU = TODO
CN = ${CN}
" > /tmp/openssl.cnf

echo -e "What is the purpose of this certificate?"
read -r purpose
echo
read -p "Do you need a SAN (y/n):  " -n 1
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sed -i '/distinguished_name/a req_extensions = v3_req' /tmp/openssl.cnf
    echo "[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]" >> /tmp/openssl.cnf

    echo -e "\nPlease list your SANs and end them with a blank line"
    i=1
    while read -r line; do
        [[ -z "${line}" ]] && break
	checkInput "${line}"
        if [[ "${isIP}" != 0 ]]; then
            echo -e "\nThe previous SAN will not be used as it contains an IPv4 address.  The SAN you provided was ${line}.  If necessary, please continue entering SANs.\n"
        elif [[ "${line}" != "${cleanInput}" ]]; then
            echo -e "\nThe previous SAN will not be used as it contains non-valid characters.  The SAN you provided was ${line}.  If necessary, please continue entering SANs.\n"
            continue
        else
            SAN+=("${line}")
            echo "DNS.${i} = ${line}" >> /tmp/openssl.cnf
            ((i++))
        fi
    done
fi

echo -e "Creating CSR...\n\n"
echo -e "Please email the following to your certificate authority\n"
echo -n "Name: "
if command -v getent > /dev/null 2>&1 ; then
    getent passwd "${SUDO_USER:-$USER}" | cut -d ':' -f 5 | cut -d ',' -f 1
else
    id -F
fi
echo "Purpose: ${purpose}
X.509 Values:"
grep "\[Subject_Name\]" -A 6 /tmp/openssl.cnf
if [[ -n "${SAN}" ]]; then
    echo -e "\nThe following SANs should already be included in the certificate request:"
    echo "${SAN[@]}" | sed 's_\s\+_\n_g'
fi
echo

openssl req -new -key "${CN}.key" -config /tmp/openssl.cnf -batch || cleanup "error"
chmod o-rwx "${CN}.key"
cleanup "quit"
