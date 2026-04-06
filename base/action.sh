#!/system/bin/sh
MODPATH=${0%/*}
PATH=$PATH:/data/adb/ap/bin:/data/adb/magisk:/data/adb/ksu/bin

# log
exec 2> $MODPATH/logs/action.log
set -x

. $MODPATH/utils.sh || exit $?

[ -f $MODPATH/disable ] && {
    echo "[-] Frida-server is disable"
    string="description=Run frida-server on boot: ❌ (failed)"
    sed -i "s/^description=.*/$string/g" $MODPATH/module.prop
    sleep 1
    exit 0
}

result="$(find_frida_pids)"
if [ -n "$result" ]; then
    echo "[-] Stopping Frida-server process: $FRIDA_PROCESS_NAME..."
    busybox kill -9 $result
else
    echo "[-] Starting Frida server..."
    start_frida_server || exit $?
fi

sleep 1

check_frida_is_up 1

#EOF
