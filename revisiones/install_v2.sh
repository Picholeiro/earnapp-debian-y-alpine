#!/bin/sh
# LICENSE_CODE ZON ISC
# Compatible with Debian (bash/coreutils) and Alpine (ash/busybox/OpenRC)

PRODUCT=$2

LCONF="/etc/earnapp/ver_conf.json"
if [ -z "$PRODUCT" ]; then
  if [ -f "$LCONF" ]; then
    if grep appid < "$LCONF" | grep "piggy" > /dev/null 2>&1; then
      PRODUCT="piggybox"
    fi
  fi
fi
if [ -z "$PRODUCT" ]; then
  PRODUCT="earnapp"
fi

VERSION="1.570.397"
PRINT_PERR=0
PRINT_PERR_DATA=0
OS_NAME=$(uname -s)
OS_ARCH=$(uname -m)
PERR_ARCH=$(uname -m | tr '[:upper:]' '[:lower:]' | tr -d -c '[:alnum:]_')
OS_VER=$(uname -v)
APP_VER=$(earnapp --version 2>/dev/null)
VER="${APP_VER:-none}"
CURR_USER=$(whoami)
RHOST=$(hostname)

# hostname -I is not available in BusyBox (Alpine)
# Detect local address using ip or ifconfig as fallback
get_local_addr()
{
    if command -v ip > /dev/null 2>&1; then
        ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' 2>/dev/null | grep -v '^127\.' | head -n 1
        # If grep -P not available (busybox), fallback
        if [ $? -ne 0 ]; then
            ip -4 addr show 2>/dev/null | grep 'inet ' | grep -v '127\.' | head -n 1 | \
                sed 's/.*inet \([0-9.]*\).*/\1/'
        fi
    elif command -v hostname > /dev/null 2>&1; then
        # Try hostname -I (Debian/Ubuntu)
        hostname -I 2>/dev/null | cut -d' ' -f1
    elif command -v ifconfig > /dev/null 2>&1; then
        ifconfig 2>/dev/null | grep 'inet ' | grep -v '127\.' | head -n 1 | \
            sed 's/.*inet \(addr:\)\{0,1\}\([0-9.]*\).*/\2/'
    fi
}

_LADDR=$(get_local_addr)
LADDR=${_LADDR:-unknown}
_IP=$(curl -q4 ifconfig.co 2>/dev/null)
IP=${_IP:-unknown}
NETWORK_RETRY=3
LOG_DIR="/etc/earnapp"
SERIAL="unknown"
SFILE="/sys/firmware/devicetree/base/serial-number"
if [ -f "$SFILE" ]; then
    SERIAL=$(sha1sum < "$SFILE" | awk '{print $1}')
fi
AUTO=0
if [ "$0" = "-y" ] || [ "$1" = "-y" ]; then
    AUTO=1
fi
RID=$(LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 32 | head -n 1)
UUID=$(cat /etc/earnapp/uuid 2>/dev/null)

# md5sum herestring (<<<) is a bashism; use echo + pipe instead
if [ -n "$UUID" ]; then
    UUID_HASH=$(echo "$UUID" | md5sum)
else
    UUID_HASH="00000000000000000000000000000000  -"
fi
# Extract hex portion and convert to number
UUID_HEX=$(echo "$UUID_HASH" | awk '{print $1}' | cut -c1-8)
UUID_I=$(printf '%d' "0x${UUID_HEX}" 2>/dev/null || echo 0)
# Absolute value and modulo
if [ "$UUID_I" -lt 0 ] 2>/dev/null; then
    UUID_I=$(( UUID_I * -1 ))
fi
UUID_N=$(( UUID_I % 100 ))
INSTALL=0
# INSTALL_PERCENT=5
# if [ -z "$UUID" ] || [ "$UUID_N" -lt "$INSTALL_PERCENT" ]; then
#    INSTALL=1
# fi
RS=""
PERR_URL="https://perr.brightdata.com/client_cgi/perr"

# Detect distro
DISTRO="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        alpine) DISTRO="alpine" ;;
        debian|ubuntu|raspbian) DISTRO="debian" ;;
        *) DISTRO="$ID" ;;
    esac
elif [ -f /etc/alpine-release ]; then
    DISTRO="alpine"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
fi

is_cmd_defined()
{
    local cmd=$1
    command -v "$cmd" > /dev/null 2>&1
    return $?
}

escape_json()
{
    local strip_nl
    local strip_tabs
    local strip_quotes
    # Use sed for portability (no bashisms)
    strip_nl=$(echo "$1" | tr '\n' ' ')
    strip_tabs=$(echo "$strip_nl" | tr '\t' ' ')
    strip_quotes=$(echo "$strip_tabs" | sed 's/"/\\"/g')
    RS=$strip_quotes
}

LOG=""
LOG_FILENAME=""
read_log()
{
    if [ -f "$LOG_FILENAME" ]; then
        LOG=$(tail -50 "$LOG_FILENAME")
        # restore after debug
        # rm -f "$LOG_FILENAME"
    fi
}

print()
{
    STR=$1
    if [ "$AUTO" = 1 ]; then
        STR="$(date -u +'%F %T') $STR"
    fi
    echo "$STR"
}

perr()
{
    local name=$1
    local note="$2"
    local filehead="$3"
    local ts
    ts=$(date +"%s")
    local ret=0
    escape_json "$note"
    note=$RS
    escape_json "$filehead"
    filehead=$RS
    local url_glob="${PERR_URL}/?id=earnapp_cli_sh_${name}"
    local url_arch="${PERR_URL}/?id=earnapp_cli_sh_${PERR_ARCH}_${name}"
    local build="Version: $VERSION\\nOS Version: $OS_VER\\nCPU ABI: $OS_ARCH\\nProduct: $PRODUCT\\nInstall ID: $RID\\nPublic IP: $IP\\nLocal IP: $LADDR\\nHost: $RHOST\\nUser: $CURR_USER\\nPlatform: $OS_NAME\\nSerial: $SERIAL\\nDistro: $DISTRO\\n"
    local data="{
        \"uuid\": \"$UUID\",
        \"client_ts\": \"$ts\",
        \"ver\": \"$VER\",
        \"filehead\": \"$filehead\",
        \"build\": \"$build\",
        \"info\": \"$note\"
    }"
    if [ "$PRINT_PERR" -eq 1 ]; then
        if [ "$PRINT_PERR_DATA" -eq 1 ]; then
            print "📧 $url_glob $data"
        else
            print "📧 $url_glob $note"
        fi
    fi
    i=0
    while [ "$i" -lt "$NETWORK_RETRY" ]; do
        if is_cmd_defined "curl"; then
            curl -s -X POST "$url_glob" --data "$data" \
                -H "Content-Type: application/json" > /dev/null
            curl -s -X POST "$url_arch" --data "$data" \
                -H "Content-Type: application/json" > /dev/null
        elif is_cmd_defined "wget"; then
            wget -S --header "Content-Type: application/json" \
                 -O /dev/null -o /dev/null --post-data="$data" \
                 --quiet "$url_glob" > /dev/null
            wget -S --header "Content-Type: application/json" \
                 -O /dev/null -o /dev/null --post-data="$data" \
                 --quiet "$url_arch" > /dev/null
        else
            print "⚠ No transport to send perr"
        fi
        ret=$?
        if [ "$ret" -eq 0 ]; then break; fi
        i=$((i + 1))
    done
}

welcome_text(){
    echo "Installing EarnApp CLI"
    echo "Welcome to EarnApp for Linux and Raspberry Pi."
    echo "EarnApp makes you money by sharing your spare bandwidth."
    echo "You will need your EarnApp account username/password."
    echo "Visit earnapp.com to sign up if you don't have an account yet"
    echo
    echo "To use EarnApp, allow BrightData to occasionally access websites \
through your device. BrightData will only access public Internet web \
pages, not slow down your device or Internet and never access personal \
information, except IP address - see privacy policy and full terms of \
service on earnapp.com."
}

ask_consent(){
    printf "Do you agree to EarnApp's terms? (Write 'yes' to continue): "
    read -r consent
}

# Convert string to lowercase (POSIX-compatible, replaces ${var,,} bashism)
to_lower()
{
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

if [ "$(id -u)" -ne 0 ]; then
   print "⚠ This script must be run as root"
   exit 1
fi

mkdir -p "$LOG_DIR"

if [ "$VER" = "$VERSION" ]; then
   perr "00_same_ver"
   print "✔ The application of the same version is already installed"
   LOG_FILENAME="$LOG_DIR/earnapp_services_restart.log"
   # Service restart: use rc-service on Alpine (OpenRC), service on Debian
   if [ "$DISTRO" = "alpine" ]; then
       {
           rc-service earnapp restart 2>/dev/null || true
           rc-service earnapp_upgrader restart 2>/dev/null || true
           rc-service earnapp status 2>/dev/null || true
           rc-service earnapp_upgrader status 2>/dev/null || true
       } >> "$LOG_FILENAME"
   else
       {
           service earnapp restart
           service earnapp_upgrader restart
           service earnapp status
           service earnapp_upgrader status
       } >> "$LOG_FILENAME"
   fi
   read_log
   perr "00_services_restart" "$VER" "$LOG"
   exit 0
fi

LOG_FILENAME="$LOG_DIR/cleanup.log"
find /tmp -name "earnapp_*" | grep -v "$VERSION" > "$LOG_FILENAME"
echo "$CLEANUP_CMD"
if [ -s "$LOG_FILENAME" ]; then
    print "✔ Cleaning up..."
    xargs rm -f < "$LOG_FILENAME"
    read_log
    perr "00_cleanup" "$VER" "$LOG"
fi

# 200MB
FREE_SPACE_MIN=$((2*100*1024*1024))

# df --total is not available in BusyBox (Alpine)
# Use portable method to get total disk space
get_free_space_blocks()
{
    if df --total / >/dev/null 2>&1; then
        # GNU coreutils (Debian)
        df --total / | grep total | awk '{print $2}'
    else
        # BusyBox (Alpine) - sum available space from all mounts
        df / | tail -1 | awk '{print $2}'
    fi
}

FREE_SPACE_BLOCKS=$(get_free_space_blocks)
FREE_SPACE_BYTES=$((FREE_SPACE_BLOCKS * 1000))

# numfmt is not available in BusyBox (Alpine)
# POSIX-compatible human-readable size formatter
human_readable_size()
{
    local bytes=$1
    if command -v numfmt > /dev/null 2>&1; then
        numfmt --to iec --format "%8.4f" "$bytes" | awk '{print $1}'
    else
        # Simple awk-based fallback
        echo "$bytes" | awk '{
            if ($1 >= 1073741824) printf "%.1fG", $1/1073741824
            else if ($1 >= 1048576) printf "%.1fM", $1/1048576
            else if ($1 >= 1024) printf "%.1fK", $1/1024
            else printf "%dB", $1
        }'
    fi
}

FREE_SPACE_PRETTY=$(human_readable_size "$FREE_SPACE_BYTES")

echo "✔ Checking prerequisites..."
if [ "$FREE_SPACE_BYTES" -lt "$FREE_SPACE_MIN" ]; then
    FREE_SPACE_MIN_PRETTY=$(human_readable_size "$FREE_SPACE_MIN")
    perr "00_disk_full" "$FREE_SPACE_PRETTY/$FREE_SPACE_MIN_PRETTY"
    FREE_SPACE_DIFF=$((FREE_SPACE_MIN - FREE_SPACE_BYTES))
    FREE_SPACE_DIFF_PRETTY=$(human_readable_size "$FREE_SPACE_DIFF")
    echo "⚠ Not enough space to install."
    echo "⚠ Please free up at least $FREE_SPACE_DIFF_PRETTY and try again."
    exit 1
fi

if [ "$INSTALL" -eq 1 ]; then
    perr "00_sh_install" "$VERSION" "$UUID_N"
fi

perr "01_start" "$VERSION" "available: $FREE_SPACE_PRETTY"
if [ "$AUTO" -eq 1 ]; then
    consent='yes'
else
    welcome_text
fi

consent_lower=$(to_lower "$consent")
while [ "$consent_lower" != 'yes' ] && [ "$consent_lower" != 'no' ]; do
    ask_consent
    consent_lower=$(to_lower "$consent")
done
if [ "$consent_lower" = 'yes' ]; then
    print "✔ Installing..."
    perr "03_consent_yes"
elif [ "$consent_lower" = 'no' ]; then
    echo "Sorry, you must accept these terms to use EarnApp."
    echo "If you decided not to use EarnApp, enter 'No'"
    perr "02_consent_no"
    exit 1
fi
STATUS_FILE="/etc/earnapp/status"
if [ ! -f "$STATUS_FILE" ]; then
    perr "04_dir_create"
    print "✔ Creating directory /etc/earnapp"
    mkdir -p /etc/earnapp
    chmod a+wr /etc/earnapp/
    touch "$STATUS_FILE"
    chmod a+wr "$STATUS_FILE"
else
    LOG_FILENAME="$LOG_DIR/dir.log"
    # ls -I is not available in BusyBox (Alpine)
    # Use ls with grep to exclude *.sent files instead
    ls -al /etc/earnapp | grep -v '\.sent$' > "$LOG_FILENAME" 2>/dev/null
    read_log
    perr "04_dir_existed" "$STATUS_FILE" "$LOG"
    print "✔ System directory already exists"
fi
if [ "$OS_ARCH" = "x86_64" ]; then
    file=$PRODUCT-x64-$VERSION
elif [ "$OS_ARCH" = "amd64" ]; then
    file=$PRODUCT-x64-$VERSION
elif [ "$OS_ARCH" = "armv7l" ]; then
    file=$PRODUCT-arm7l-$VERSION
elif [ "$OS_ARCH" = "armv6l" ]; then
    file=$PRODUCT-arm7l-$VERSION
elif [ "$OS_ARCH" = "aarch64" ]; then
    file=$PRODUCT-aarch64-$VERSION
elif [ "$OS_ARCH" = "arm64" ]; then
    file=$PRODUCT-aarch64-$VERSION
else
    perr "10_arch_other" "$OS_ARCH"
    file=$PRODUCT-arm7l-$VERSION
fi
print "✔ Fetching $file"
perr "15_fetch_start" "$file"
FILENAME="/tmp/earnapp_$VERSION"
LOG_FILENAME="$LOG_DIR/earnapp_fetch.log"
BASE_URL="${BASE_URL:-https://cdn-earnapp.b-cdn.net/static}"
if wget -c "$BASE_URL/$file" \
    -O "$FILENAME" 2>"$LOG_FILENAME"; then
    read_log
    perr "17_fetch_finished" "$file" "$LOG"
else
    read_log
    perr "16_fetch_failed" "$file" "$LOG"
    print "⚠ Failed"
    exit 1
fi
echo | md5sum "$FILENAME"
chmod +x "$FILENAME"
INSTALL_CMD="$FILENAME install"
MAIN_EXE="/usr/bin/earnapp"
MAIN_EXE_BAK="/usr/bin/earnapp_bak"
if [ "$INSTALL" -eq 1 ]; then
    if [ -f "$MAIN_EXE" ]; then
        mv -f "$MAIN_EXE" "$MAIN_EXE_BAK"
    fi
    mv -f "$FILENAME" "$MAIN_EXE"
    INSTALL_CMD="$MAIN_EXE finish_install"
fi
if [ "$AUTO" -eq 1 ]; then
    INSTALL_CMD="$INSTALL_CMD --auto"
fi
LOG=""
LOG_FILENAME="$LOG_DIR/earnapp_install.log"
if [ "$AUTO" -eq 1 ]; then
    INSTALL_CMD="$INSTALL_CMD 2>$LOG_FILENAME"
fi
print "✔ Running $INSTALL_CMD"
perr "20_install_run" "$INSTALL_CMD"
eval $INSTALL_CMD
read_log
perr "25_install_finished" "$INSTALL_CMD" "$LOG"
INSTALLED_VER=$(cat /etc/earnapp/ver 2>/dev/null)
if [ "$INSTALLED_VER" = "$VERSION" ]; then
    if [ -f "$MAIN_EXE_BAK" ]; then
        rm -f "$MAIN_EXE_BAK"
    fi
    print "✔ Installation complete"
    echo
    perr "30_install_success" "$VERSION" "$LOG"
    exit 0
else
    LOG_FILENAME="$LOG_DIR/install_bash.log"
    if [ -f "$LOG_FILENAME" ]; then
        read_log
    fi
    print "⚠ Installation failed"
    echo
    perr "29_install_fail" "$INSTALLED_VER" "$LOG"
    if [ -f "$MAIN_EXE_BAK" ]; then
        mv -f "$MAIN_EXE_BAK" "$MAIN_EXE"
    fi
    exit 1
fi
