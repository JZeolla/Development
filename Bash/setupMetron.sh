#!/usr/bin/env bash
# To enable and disable tracing use:  set -x (On) set +x (Off)
# To terminate the script immediately after any non-zero exit status use:  set -e

# =========================
# Author:          Jon Zeolla (JZeolla, JonZeolla)
# Last update:     2016-11-22
# File Type:       Bash Script
# Version:         0.29
# Repository:      https://github.com/JZeolla/Development
# Description:     This is a helper script to configure an Apache Metron (incubating) full-dev or quick-dev environment.
#
# Notes
# - Anything that has a placeholder value is tagged with TODO.
# - This needs better error handling and some sort of logging.
# - This needs to be less prone to overwriting, should be idempotent, and have better checking/validation.  Once this happens, it can be used to install on top of existing CentOS 6 machines.
# - In order to pull this down you need to manually install git.
# - This should provide a way of overriding the built-in versions (set that override=1, if there are errors with _downloadit or similar, inform the user appropriately)
# - Make sure to specify the build for component[virtualbox]
# - Should add signature validation
# - Now that this is working on CentOS 6.8, I should be able to make it more flexible and work on 7 as well as other distros.
#
# =========================


## Global Instantiations
# Static Variables
declare -r usrCurrent="${SUDO_USER:-${USER}}"
declare -r unusedUID="$(awk -F: '{uid[$3]=1}END{for(x=1000;x<=1100;x++) {if(uid[x] != ""){}else{print x; exit;}}}' /etc/passwd)"
declare -r metronRepo="https://github.com/apache/incubator-metron"
declare -r OPTSPEC=':fhsu:v-:'
# Potential TOCTOU issue with startTime
declare -r startTime="$(date +%Y-%m-%d_%H-%M)"
declare -r txtDEFAULT='\033[0m'
declare -r txtVERBOSE='\033[33;34m'
declare -r txtINFO='\033[0;30m'
declare -r txtWARN='\033[0;33m'
declare -r txtERROR='\033[0;31m'
declare -r txtABORT='\033[1;31m'
# Array Variables
declare -a downloaded
declare -a issues
declare -A component
declare -A OS
# Integer Variables
declare -i exitCode=0
declare -i verbose=0
declare -i usetheforce=0
declare -i startitup=0
declare -i showthehelp=0
# String Variables
declare -- deployChoice=""
declare -- action=""


## Populate associative array
component[ansible]="2.0.0.2"
component[vagrant]="1.8.1"
component[virtualbox]="5.0.28_111378"
component[python]="2.7.11"
component[maven]="3.3.9"
component[ez_setup]="bootstrap"
component[metron]="master"


## Functions
function _getDir() {
    if [[ "${component[${1}]}" != "latest" && "${component[${1}]}" != "master" ]]; then
        echo "/usr/local/${1}/${component[${1}]}"
    else
        echo "/usr/local/${1}/${startTime}"
    fi
}

function _cleanup() {
    ## Cleanup temporary files, remove empty directories, fix ownership, etc.
    # Make sure the user was created, if not then there is no cleanup to attempt
    if getent passwd ${usrSpecified} > /dev/null; then
        for downloadedFile in "${downloaded[@]}"; do
            if [[ -n "${downloadedFile}" ]]; then
                if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Removing ${downloadedFile}"; fi
                rm -f "${downloadedFile}"
            fi
        done

        for k in "${!component[@]}"; do
            if [[ -d "$(_getDir "${k}")" ]]; then
                if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Recursively chowning $(_getDir ${k}) to have a owner and group of ${usrSpecified}"; fi
                sudo chown -R "${usrSpecified}:" "$(_getDir ${k})"
            elif [[ -d "$(_getDir "${k}")" ]]; then
                if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Deleting empty directories related to ${k}"; fi
                rmdir "$(_getDir "${k}")" "$(_getDir "${k}")/.."
            fi
        done
    else
        if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "${usrSpecified} was never created, skipping cleanup"; fi
    fi
    
    if [[ "${verbose}" == "1" ]]; then
        for issue in "${issues[@]}"; do
            _feedback VERBOSE "Issue encountered - ${issue}"
        done
    fi
}

function _quit() {
        exitCode="${1:-0}"
        _cleanup
        if [[ "${verbose}" == "1" ]]; then
            _feedback VERBOSE "$(hostname):$(readlink -f ${0}) $* completed at [`date`] as PID $$ with an exit code of ${exitCode}"
        fi
        exit "${exitCode}"
}

function _feedback() {
    color="txt${1:-DEFAULT}"
    if [[ "${1}" == "ABORT" ]]; then
        # TODO: Test stderr
        >&2 echo -e "${!color}ERROR:\t${2}, aborting...${txtDEFAULT}"
        _quit 1
    elif [[ "${1}" != "INFO" && "${1}" != "VERBOSE" ]]; then
        exitCode=1
        issues+=("${2}")
        >&2 echo -e "${!color}${1}:\t${2}${txtDEFAULT}"
    else
        echo -e "${!color}${1}:\t${2}${txtDEFAULT}"
    fi
}

function _downloadit() {
    currComponent="$(basename $(dirname ${PWD}))"
    theFile="${1##*/}"

    # Make sure you're in one of the right dirs
    if [[ "$(_getDir ${currComponent})" == "${PWD}" ]]; then
        # Download the file and check for any issues
        wget -q -N "${1}"
        if [[ "$?" != 0 ]]; then
            _feedback ERROR "Issue retrieving ${1}"
        else
            downloaded+=("$(_getDir ${currComponent})"/"${theFile}")
        fi
    else
        _feedback ABORT "Downloading ${theFile} in the wrong place - currently in ${PWD}"
    fi
}

function _managePackages() {
    # Consider using https://github.com/icy/pacapt at some point?
    case "${1}" in
        install)
            action="install" ;;
        groupinstall)
            action="groupinstall" ;;
        *)
            _feedback ABORT "Issue identifying package management action to take" ;;
    esac

    if [[ "${OS[packagemanager]}" == "yum" && "${OS[supported]}" == "true" ]]; then
        for pkg in ${2}; do
	    # This handles yum installs of local RPMs, remote RPMs, and packages
            rpmQA=$(awk -F\/ '{print $NF}' <<< "${pkg}")
	    rpm -qa | grep -qw "${rpmQA%.*}" || sudo yum -y -q "${action}" "${pkg}" || _feedback ERROR "Issue performing \`sudo yum -y -q ${action} ${pkg}\` successfully"
	done
    elif [[ "${OS[packagemanager]}" == "brew" && "${OS[supported]}" == "true" ]]; then
        # TODO:  homebrew support
        _feedback ABORT "Homebrew is not yet supported"
    elif [[ "${OS[packagemanager]}" == "Unknown" && "${OS[supported]}" == "true" ]]; then
        _feedback ABORT "Unknown package manager"
    else
        _feedback ABORT "Unknown error validating OS package manager"
    fi
}

function _showHelp() {
    # Note that the here-doc is purposefully using tabs, not spaces, for indentation
    cat <<- HEREDOC
	Usage: ${0##*/} [-fhs] [-u USER] [--] <DEPLOYMENT CHOICE>

	-f|--force			Do not prompt before proceeding.
	-h|--help			Print this help.
	-s|--start			Start Metron by default.
	-u|--user			Specify the user.
	-v|--verbose			Add verbosity.
	DEPLOYMENT CHOICE		Choose one of QUICK or FULL.
	HEREDOC

    _quit
}


## Handle signals
# trap common kill signals
# TODO: Test this
trap '_feedback ABORT "Received a kill signal on $(hostname) while running $(readlink -f ${0}) $* at $(date +%Y-%m-%d_%H:%M)"' SIGINT SIGTERM SIGHUP


## Initial checks
# Setup options
# TODO: Add some better error cases below
while getopts "${OPTSPEC}" optchar; do
    case ${optchar} in
        -)
            # TODO: This needs testing
            # Note that getopts does not perform OPTERR checking nor option-argument parsing for this section
            # For details, see http://stackoverflow.com/questions/402377/using-getopts-in-bash-shell-script-to-get-long-and-short-command-line-options/7680682#7680682
            case "${OPTARG}" in
                force)
                    usetheforce=1 ;;
                help)
                    showthehelp=1 ;;
                start)
                    startitup=1 ;;
                user)
                    # TODO: Testing
                    # usrSpecified="${!OPTIND}" ;;
                    echo Try1: usrSpecified="${!OPTIND}"
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    echo usrSpecified="${val}"
                    echo "Parsing option: '--${OPTARG}', value: '${val}'"
                    ;;
                user=*)
                    echo Try1: usrSpecified="${OPTARG#*=}"
                    val=${OPTARG#*=}
                    opt=${OPTARG%=$val}
                    echo "Parsing option: '--${opt}', value: '${val}'"
                    ;;
                verbose)
                    verbose=1 ;;
                *)
                    if [ "${OPTERR}" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]; then
                        _feedback ERROR "Unknown option --${OPTARG}"
                        showthehelp=1
                    fi
                    ;;
            esac ;;
        f)
            usetheforce=1 ;;
        h)
            showthehelp=1 ;;
        s)
            startitup=1 ;;
        u)
            usrSpecified="${OPTARG}" ;;
        v)
            verbose=1 ;;
        '?')
            _feedback ERROR "Invalid option: -${OPTARG}"
            showthehelp=1
            ;;
    esac
done

shift "$((OPTIND-1))"

if [[ "${showthehelp}" == "1" ]]; then
    _showHelp
fi

if ! sudo -v > /dev/null 2>&1; then
    _feedback ABORT "No sudo access detected for this user"
fi

# Check remaining argument
case "${1}" in
    [fF][uU][lL][lL]|[fF][uU][lL][lL]-[dD][eE][vV]|[fF][uU][lL][lL]-[dD][eE][vV]-[pP][lL][aA][tT][fF][oO][rR][mM])
        deployChoice="full-dev-platform" ;;
    [qQ][uU][iI][cC][kK]|[qQ][uU][iI][cC][kK]-[dD][eE][vV]|[qQ][uU][iI][cC][kK]-[dD][eE][vV]-[pP][lL][aA][tT][fF][oO][rR][mM])
        deployChoice="quick-dev-platform" ;;
    *)
        _showHelp
        _feedback ABORT "Invalid argument, please choose either full or quick for your deployment choice" ;;
esac


# Validate the OS
# TODO: Test this more comprehensively
case "${OSTYPE}" in
    darwin*)
        OS[distro]="Mac"
        OS[version]="${OSTYPE:6}"
        # TODO: Purposefully still not supported by default, but maybe soon
        if [[ "${OS[version]}" == "16" ]]; then
            OS[supported]="false"
        else
            OS[supported]="false"
        fi
        ;;
    linux*)
        if [[ -r /etc/centos-release ]]; then
            OS[distro]="$(awk -F\  '{print $1}' /etc/centos-release)"
            OS[version]="$(awk -F\  '{print $(NF-1)}' /etc/centos-release)"
            if [[ "${OS[distro]}" == "CentOS" && "${OS[version]}" == "6.8" ]]; then
                OS[supported]="true"
            else
                OS[supported]="false"
            fi
        else
            OS[distro]="Linux"
            OS[version]="Unknown"
            OS[supported]="false"
        fi
        ;;
    bsd*)
        OS[distro]="BSD"
        OS[version]="Unknown"
        OS[supported]="false" ;;
    msys*)
        OS[distro]="Windows"
        OS[version]="Unknown"
        OS[supported]="false" ;;
    solaris*)
        OS[distro]="Solaris"
        OS[version]="Unknown"
        OS[supported]="false" ;;
    *)
        OS[distro]="Unknown"
        OS[version]="Unknown"
        OS[supported]="false" ;;
esac

if [[ "${OS[supported]}" == "true" ]]; then
    # TODO: Handle this better
    if command -v yum > /dev/null 2>&1 ; then
        OS[packagemanager]="yum"
    else
        OS[packagemanager]="Unknown"
    fi
    if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Your OS is supported (Distro: ${OS[distro]}, Version ${OS[version]})"; fi
elif [[ "${OS[supported]}" == "false" ]]; then
    _feedback ABORT "Your OS is not supported (Distro: ${OS[distro]}, Version ${OS[version]})"
else
    _feedback ABORT "Unknown error checking OS support"
fi


# Ensure basic tool(s)
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing some basic tools"; fi
if [[ "${OS[distro]}" == "CentOS" && "${OS[supported]}" == "true" ]]; then
    if ! command -v wget > /dev/null 2>&1 ; then
        _managePackages "install" "wget"
    fi
    _managePackages "install" "yum-utils"
fi

# Check network connectivity
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Checking network connectivity"; fi
wget -q --spider 'www.github.com' || _feedback ABORT "Unable to contact github.com"

# Check for virtualization extensions
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Ensuring that virtualization extensions are available"; fi
if ! egrep '(vmx|svm)' /proc/cpuinfo > /dev/null 2>&1 ; then
    _feedback ABORT "Your system does not support virtualization, which is required for this system to run Metron using vagrant and virtualbox"
fi

# Ask the user for confirmation
if [[ "${verbose}" == "1" ]]; then
    for k in "${!component[@]}"; do
        if [[ "${component[${k}]}" != "latest" && "${component[${k}]}" != "master" ]]; then
            _feedback VERBOSE "Planning to install ${k} ${component[${k}]}"
        else
            _feedback VERBOSE "Planning to install the latest version of ${k} as of ${startTime}"
        fi
    done
fi

# TODO: This needs tested
if [[ "${usetheforce}" != "1" ]]; then
    if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Asking the user for confirmation"; fi
    while [ -z "${prompt}" ]; do
        read -p "This script is intended to be run on a fresh CentOS 6.8 installation and may have unintended side effects otherwise.  Do you want to continue (y/N)? " prompt
        case "${prompt}" in
            [yY]|[yY][eE][sS])
                _feedback INFO "Please note that this script may take a long time (15+ minutes) to complete"
                sleep 1s
                _feedback INFO "Continuing..." ;;
            ""|[nN]|[nN][oO])
                _feedback ABORT "Did not want to continue" ;;
            *)
                _feedback ABORT "Unknown response" ;;
        esac
    done
fi


## Check access which will be required later (filesystem ACLs, etc.)
# TODO


## Beginning of main script
# Default the user to the current user if it wasn't set
usrSpecified="${usrSpecified:-$USER}"

# Install pre-reqs
if [[ "${OS[distro]}" == "CentOS" ]]; then
    if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing some CentOS pre-reqs"; fi
    # Be aware that the following commands may give a "repomd.xml does not match metalink for epel." error every once in a while due to epel resynchronization.
    _managePackages "install" "http://mirror.redsox.cc/pub/epel/6/i386/epel-release-6-8.noarch.rpm"
    # Setup GUI (assuming minimal install)
    _managePackages "groupinstall" "Development tools" "X Window System" "Desktop" "Desktop Platform"
    _managePackages "install" "gdm zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel dkms"
    if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Making sure the system will boot into the GUI"; fi
    sudo sed -ie "26s|^id:3|id:5|" /etc/inittab || _feedback ERROR "Unable to modify /etc/inittab"
fi

# Set up a user
if [[ "${usrSpecified}" != "${USER}" ]]; then
    if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Creating a new user and group of ${usrSpecified}"; fi
    sudo groupadd -g "${unusedUID}" "${usrSpecified}" || _feedback ERROR "Unable to create group ${usrSpecified} with GID ${unusedUID}"
    sudo useradd -d "/home/${usrSpecified}" -g "${usrSpecified}" -G wheel -s /bin/bash -u "${unusedUID}" "${usrSpecified}" || _feedback ERROR "Unable to create user ${usrSpecified} with UID ${unusedUID}"
    sudo passwd "${usrSpecified}" || _feedback ERROR "Unable to reset the password for ${usrSpecified}"
    if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Giving ${usrSpecified} full sudo access"; fi
    sudo sed -ie "98s|^# ||" /etc/sudoers || _feedback ERROR "Unable to modify /etc/sudoers"
fi

# Setup some directories
for k in "${!component[@]}"; do
    if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Setting up an install directory for ${k}"; fi
    sudo mkdir -p "$(_getDir ${k})" || _feedback ERROR "Unable to mkdir $(_getDir ${k})"
    sudo chown "${usrSpecified}:" "$(_getDir ${k})" || _feedback ERROR "Unable to chown ${usrSpecified}: $(_getDir ${k})"
done

# Setup python
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing python into $(_getDir "python")"; fi
cd "$(_getDir "python")"
_downloadit "https://www.python.org/ftp/python/${component[python]}/Python-${component[python]}.tgz"
tar -xvf "Python-${component[python]}.tgz" --strip 1 || _feedback ERROR "Unable to untar $(_getDir "python")/Python-${component[python]}.tgz"
./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib" || _feedback ERROR "Unable to configure python"
make && sudo make altinstall || _feedback ERROR "Unable to \`sudo make altinstall\` python"
sudo ln -s "/usr/local/bin/python${component[python]:0:3}" /usr/local/bin/python || _feedback ERROR "Unable to link python${component[python]:0:3} to /usr/local/bin/python"
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing ez_setup into $(_getDir "ez_setup")"; fi
cd "$(_getDir "ez_setup")"
_downloadit "https://bootstrap.pypa.io/ez_setup.py"
sudo /usr/local/bin/python ez_setup.py || _feedback ERROR "Unable to setup ez_python.py"
sudo "/usr/local/bin/easy_install-${component[python]:0:3}" pip || _feedback ERROR "Unable to setup pip"
sudo /usr/local/bin/pip -q install virtualenv paramiko PyYAML Jinja2 httplib2 six setuptools || _feedback ERROR "Unable to install tools with pip"

# Setup ansible
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing ansible using pip"; fi
sudo /usr/local/bin/pip -q install "ansible==${component[ansible]}" || _feedback ERROR "Unable to install ansible"

# Setup maven
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing maven into $(_getDir "maven")"; fi
cd "$(_getDir "maven")"
_managePackages "install" "java-1.8.0-openjdk-devel"
_downloadit "http://mirrors.ibiblio.org/apache/maven/maven-${component[maven]:0:1}/${component[maven]}/binaries/apache-maven-${component[maven]}-bin.tar.gz"
tar -xvf "apache-maven-${component[maven]}-bin.tar.gz" --strip 1 || _feedback ERROR "Unable to untar $(_getDir "maven")/apache-maven-${component[maven]}-bin.tar.gz"
echo "export M2_HOME=$(_getDir "maven")" | sudo tee /etc/profile.d/maven.sh > /dev/null || _feedback ERROR "Unable to overwrite /etc/profile.d/maven.sh"
echo "export PATH=${M2_HOME}/bin:${PATH}" | sudo tee -a /etc/profile.d/maven.sh > /dev/null || _feedback ERROR "Unable to append to /etc/profile.d/maven.sh"
sudo chmod o+x /etc/profile.d/maven.sh || _feedback ERROR "Unable to chmod o+x /etc/profile.d/maven.sh"
/etc/profile.d/maven.sh || _feedback ERROR "Unable to run /etc/profile.d/maven.sh"
sudo ln -s "/usr/local/maven/${component[maven]}/bin/mvn" /usr/local/bin/mvn || _feedback ERROR "Unable to link /usr/local/maven/${component[maven]}/bin/mvn to /usr/local/bin/mvn"

# Setup virtualbox
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing virtualbox into $(_getDir "virtualbox")"; fi
cd "$(_getDir "virtualbox")"
_downloadit "http://download.virtualbox.org/virtualbox/${component[virtualbox]%%_*}/VirtualBox-${component[virtualbox]:0:3}-${component[virtualbox]}_el6-1.x86_64.rpm"
_managePackages "install" "VirtualBox-${component[virtualbox]:0:3}-${component[virtualbox]}_el6-1.x86_64.rpm"
sudo usermod -a -G vboxusers "${usrSpecified}" || _feedback ERROR "Unable to add ${usrSpecified} to the vboxusers group"
if [[ "${usrCurrent}" == "${usrSpecified}" && $(getent group vboxusers | grep "${usrSpecified}") ]] && ! $(id -Gn | grep vboxusers) ; then
    _feedback WARN "In order to take advantage of new group memberships you should log out and log in again"
fi

# Setup vagrant
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing vagrant into $(_getDir "vagrant")"; fi
cd "$(_getDir "vagrant")"
_downloadit "https://releases.hashicorp.com/vagrant/${component[vagrant]}/vagrant_${component[vagrant]}_x86_64.rpm"
_managePackages "install" "vagrant_${component[vagrant]}_x86_64.rpm"
vagrant plugin install vagrant-hostmanager || _feedback ERROR "Unable to install the vagrant-hostmanager vagrant plugin"

# Setup Metron
if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Installing metron into $(_getDir "metron")"; fi
# TODO: Allow a way to pull down and setup a specific, older version by checking out the tag
cd "$(_getDir "metron")"
git clone -q --recursive ${metronRepo} . || _feedback ABORT "Unable to git clone metron"
/usr/local/bin/mvn clean package -DskipTests || _feedback ABORT "Issue building Metron"

# Start Metron, if appropriate
if [[ "${startitup}" == "1" ]]; then
    if [[ "${usrCurrent}" == "${usrSpecified}" ]]; then
        if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Starting up metron's \"${deployChoice}\""; fi
        cd "$(_getDir "metron")/metron-deployment/vagrant/${deployChoice}"
        sg vboxusers -c "vagrant up" || _feedback ERROR "Unable to run sg vboxusers -c \"vagrant up\""
    elif sudo -v -u "${usrSpecified}" > /dev/null 2>&1 ; then
        if [[ "${verbose}" == "1" ]]; then _feedback VERBOSE "Starting up metron's \"${deployChoice}\" as \"${usrSpecified}\""; fi
        sudo -u "${usrSpecified}" vagrant up
    else
        _feedback ABORT "Unable to run vagrant up as \"${usrSpecified}\""
    fi
fi

## Exit appropriately
_quit
