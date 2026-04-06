#!/bin/sh
MODPATH=${0%/*}
FRIDA_CONFIG="$MODPATH/frida.config"
FRIDA_PROCESS_NAME="frida-server"
FRIDA_PORT=""
FRIDA_LISTEN_HOST="127.0.0.1"
PATH="$MODPATH/bin:$PATH:/data/adb/ap/bin:/data/adb/magisk:/data/adb/ksu/bin"

# log
exec 2> $MODPATH/logs/utils.log
set -x

load_frida_config() {
    if [ -f "$FRIDA_CONFIG" ]; then
        config_process_name="$(sed -n 's/^FRIDA_PROCESS_NAME=//p' "$FRIDA_CONFIG" | head -n 1)"
        config_port="$(sed -n 's/^FRIDA_PORT=//p' "$FRIDA_CONFIG" | head -n 1)"
        config_listen_host="$(sed -n 's/^FRIDA_LISTEN_HOST=//p' "$FRIDA_CONFIG" | head -n 1)"

        case "$config_process_name" in
            ''|*[!A-Za-z0-9._-]*)
                ;;
            *)
                FRIDA_PROCESS_NAME="$config_process_name"
                ;;
        esac

        case "$config_port" in
            ''|*[!0-9]*)
                ;;
            *)
                FRIDA_PORT="$config_port"
                ;;
        esac

        case "$config_listen_host" in
            ''|*[!0-9A-Fa-f:.]*)
                ;;
            *)
                FRIDA_LISTEN_HOST="$config_listen_host"
                ;;
        esac
    fi

    FRIDA_BIN="$MODPATH/bin/$FRIDA_PROCESS_NAME"
}

find_frida_pids() {
    busybox pgrep "$FRIDA_PROCESS_NAME"
}

get_frida_port_label() {
    if [ -n "$FRIDA_PORT" ]; then
        printf '%s' "$FRIDA_PORT"
    else
        printf '%s' "default"
    fi
}

set_module_description() {
    status="$1"
    port_label="$(get_frida_port_label)"
    string="description=Run frida-server on boot [port: $port_label]: $status"
    sed -i "s/^description=.*/$string/g" "$MODPATH/module.prop"
}

load_frida_config

check_frida_is_up() {
    if [ -n "$1" ]; then
        timeout="$1"
    else
        timeout=4
    fi
    counter=0

    while [ $counter -lt $timeout ]; do
        result="$(find_frida_pids)"
        if [ -n "$result" ]; then
            echo "[-] Frida-server is running... 💉😜"
            set_module_description "✅ (active)"
            break
        else
            echo "[-] Checking Frida-server status: $counter"
            counter=$((counter + 1))
        fi
        sleep 1.5
    done

    if [ $counter -ge $timeout ]; then
        set_module_description "❌ (failed)"
    fi
}

start_frida_server() {
  if [ ! -x "$FRIDA_BIN" ]; then
    echo "[-] Frida binary not found: $FRIDA_BIN"
    set_module_description "❌ (missing binary)"
    return 1
  fi

  if [ -n "$FRIDA_PORT" ]; then
    echo "[-] Starting Frida-server as $FRIDA_PROCESS_NAME on $FRIDA_LISTEN_HOST:$FRIDA_PORT"
    "$FRIDA_BIN" -D -l "$FRIDA_LISTEN_HOST:$FRIDA_PORT"
  else
    echo "[-] Starting Frida-server as $FRIDA_PROCESS_NAME on default port"
    "$FRIDA_BIN" -D
  fi
}

wait_for_boot() {
  while true; do
    result="$(getprop sys.boot_completed)"
    if [ $? -ne 0 ]; then
      exit 1
    elif [ "$result" = "1" ]; then
      break
    fi
    sleep 3
  done
}

#EOF
