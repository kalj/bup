#!/bin/bash
#
# @author Karl Ljungkvist


# bup_prog="rsync -zavh --delete --progress"
bup_prog="echo rsync -zavh --delete --progress"

function check_for_error()
{
    if [ $? != 0 ] ; then
        >&2 echo "$(date +"%F %T"): $@"
        exit 1
    fi
}


while [ $# -gt 0 ]
do
    case $1
        in
        -n)
            BUP_PROG="$BUP_PROG --dry-run"
            shift 1
            ;;
        *)
            echo "The arguments to use are"
            echo "-n: Dry run"
            # echo "-all: Do not exclude anything"
            # echo "-vbox: Back up VirtualBox windows image"
            exit
            ;;
    esac
done


for target in "${target_list[@]}" ; do

    eval dest=\"\$target_${target}_destination\"
    eval src=\"\$target_${target}_source\"
    eval exclude=\"\$target_${target}_exclude\"
    eval prevlink=\"\$target_${target}_previous_link\"

    flags="-zavh --delete --progress"

    if [[ -n "$prevlink" ]] ; then
        flags+=" -H --link-dest=${prevlink}"
    fi


    $bup_prog $flags $exclude "${src}" "${core_backup_host}:${dest}"
    check_for_error "Backup failed for copying target ${target}"

done

# $BUP_PROG  /usr/local/bin/  "$BUP_DST/usr_local_bin"
# check_for_error "Backup failed for copying /usr/local/bin"

# $BUP_PROG /usr/share/i18n/locales/en_SE "$BUP_DST"
# check_for_error "Backup failed for copying custom locale"

# PKGLIST=`tmpfile`
# dpkg -l | grep '^ii' | \awk '{print $2}' | sort > ${PKGLIST}
# $BUP_PROG ${PKGLIST} "$BUP_DST/package_list"
# check_for_error "Backup failed for copying package list"
# rm ${PKGLIST}
