#!/bin/bash
absolute_path=$(dirname "$(realpath "$BASH_SOURCE")")
absolute_argument=$(realpath "$1")
argument_filename=$(basename "$1")
requirements=( "make" "git" "automake" "autoreconf" "texi2pdf" "tar" "xz" "wget" "bison" "gperf" "perl" "gettext" "autopoint" "gcc" "strace" "yara" )
cleanup=()
if [[ ! -e "$absolute_path/config.txt" ]]; then
    touch "$absolute_path/config.txt"
fi
config_file=$(cat "$absolute_path/config.txt")
if [[ "$(id -u)" != 0 ]]; then
    echo "Run script as root user"
    exit
fi
if [[ ! -e "$absolute_path/malware_rules" || ! -e "$absolute_path/malware_rules/main.yar" ]]; then
    echo "Why you deleted malware rules directory?"
    exit
fi
for app in "${requirements[@]}"; do
    if [[ "$(command -v $app &>/dev/null ; echo $?)" != 0 ]]; then
        echo "Command not found $app"
        exit
    fi
done
if [[ -e $1 && -x $1 && -n $1 ]]; then
    
    yara -w -s "$absolute_path/malware_rules/main.yar" $1 
    
    if [[ $? != 0 ]]; then
        echo "Static analysis failed (Try providing full path to executable file)"
        exit
    fi
    
    cd "$absolute_path" || exit

    mkdir -p root/bin && \
    mkdir -p root/proc && \
    mkdir -p root/etc && \
    mkdir -p root/var && \
    mkdir -p root/lib && \
    mkdir -p root/lib64 && \
    mkdir -p root/lib32 && \
    mkdir -p root/dev && \
    mkdir -p root/sys && \
    mkdir -p root/tmp && \
    mknod root/dev/null c 1 3 && \
    chmod 666 /dev/null && \
    cp -nrL /lib/x86_64-linux-gnu/* root/lib/ &>/dev/null && \
    cp -nrL /lib64/* root/lib64/ &>/dev/null && \
    cp -nrL /lib32/* root/lib32/ &>/dev/null && \
    cp -n "$absolute_argument" root/tmp/ && \
    chmod 777 "root/tmp/$argument_filename" && \
    cp -n /bin/bash root/bin/ && \
    cp -n /bin/strace root/bin/ && \
    touch root/tmp/strace.log && \
    chmod 755 root/tmp/strace.log
    
    while IFS= read -r option; do
        if [[ $option == "set proc" ]]; then
            mount --bind /proc "$absolute_path/root/proc" && cleanup+=( "umount $absolute_path/root/proc" )
        elif [[ $option == "set dev" ]]; then
            mount --bind /dev "$absolute_path/root/dev" && cleanup+=( "umount $absolute_path/root/dev" )
        elif [[ $option == "set etc" ]]; then
            mount --bind /etc "$absolute_path/root/etc" && cleanup+=( "umount $absolute_path/root/etc" )
        elif [[ $option == "set sys" ]]; then
            mount --bind /sys "$absolute_path/root/sys" && cleanup+=( "umount $absolute_path/root/sys" )
        elif [[ $option == "set var" ]]; then
            mount --bind /var "$absolute_path/root/var" && cleanup+=( "umount $absolute_path/root/var" )
        fi
    done <<< "$config_file"


    if [[ -e coreutils && -d coreutils ]]; then
        cd coreutils || exit
        make install &>/dev/null
    else
        git clone git://git.sv.gnu.org/coreutils -q && \
        git config --global --add safe.directory "$absolute_path/coreutils" && \
        export FORCE_UNSAFE_CONFIGURE=1 && \
        cd coreutils && \
        ./bootstrap &>/dev/null && \
        ./configure --prefix="$absolute_path/root" &>/dev/null && \
        make &>/dev/null && \
        make install &>/dev/null
        git config --global --unset-all --fixed-value safe.directory "$absolute_path/coreutils"
    fi
    cd "$absolute_path" || exit
    chroot "$absolute_path/root" /bin/bash -c "strace -f '/tmp/$argument_filename'" &>/tmp/strace.log
    if [[ ${#cleanup[@]} != 0 ]]; then
        for (( i=0; i<${#cleanup[@]}; i++ )); do
            ${cleanup[i]}
        done
    fi
else
    echo "Usage $0 <EXECUTABLE_FILE_PATH>"
    exit
fi
