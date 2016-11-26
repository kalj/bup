#!/bin/bash
#
#
#
# @author Karl Ljungkvist


# bup_cmd="rsync -zavh --delete --progress"
# bup_cmd="rsync --dry-run -zavh --delete --progress"
bup_cmd="echo rsync -zavh --delete --progress"

# internal files
conf_file=$HOME/.bupconf
bup_dir=$HOME/.bup
timestamp_file=${bup_dir}/stamp
lockdir=/tmp/bup-lock-dir
lockpidfile=/tmp/bup-lock-dir/pid

# log files
log_file=${bup_dir}/log
detailed_file=${bup_dir}/detailed
debug_file=${bup_dir}/debug

#==============================================================================
# functions
#==============================================================================

# parser

function parse_conf()
{
    conffile="$1"

    target_list=()

    while read -r line ;
    do

        if [[ "$line" == \[* ]] ; then
            a="$(echo "$line" | sed 's/\[\s*\(.*\)\s*\]/\1/')"

            if [[ "$a" == target* ]] ;
            then

                trg="$(echo "$a" | sed 's/.*\"\(.*\)\"/\1/')"

                target_list+=("${trg}")

                currentsection="target_${trg}"
            else
                currentsection="$a"
            fi
        elif echo "$line" | grep '=' &>/dev/null ;
        then

            read var val < <(echo "$line" | sed 's|\s*\(.*\)\s*=\s*\(.*\)\s*|\1 \2|')

            prefix="${currentsection}_"

            # use empty prefix for core variables
            if [[ "$currentsection" == core* ]] ;
            then
                prefix=
                # echo "${prefix}$var=$val"

            fi

            if [ "$var" == exclude ] ;
            then
                declare -g "${prefix}exclude+= --exclude $val"
            else
                declare -g "${prefix}$var=$val"
            fi

            # else
            # echo "found something else: $line"
        fi
    done < <(cat "$conffile" )
}

function log()
{

    local level=0
    if [ "$1" == "-v" ] ; then
        shift 1
        level=1
    elif [ "$1" == "-dbg" ] ; then
        shift 1
        level=2
    fi

    msg="$(date +"%F %T"): $@"

    echo "$msg" >> $debug_file

    if [ $level -lt 2 ] ; then
        echo "$msg" >> $detailed_file
    fi

    if [ $level -lt 1 ] ; then
        echo "$msg" >> $log_file
    fi
}


# this runs all backups
function run_backups()
{
    for target in "${target_list[@]}" ; do

        eval dest=\"\$target_${target}_destination\"
        eval src=\"\$target_${target}_source\"
        eval exclude=\"\$target_${target}_exclude\"
        eval prevlink=\"\$target_${target}_previous_link\"

        flags=""

        if [[ -n "$prevlink" ]] ; then
            flags+=" -H --link-dest=${prevlink}"
        fi


        $bup_cmd $flags $exclude "${src}" "${backup_host}:${dest}"

        s=$?
        if [  $s == 23 ] ; then
            log -v "Backup of ${src} to ${backup_host}:${dest} finished with partial file transfer errors"
        elif [ $s != 0 ] && [  $s != 23 ] ; then
            log -v "Backup of ${src} to ${backup_host}:${dest} failed with status $s"

            return 1
        else
            log -v "Backup of ${src} to ${backup_host}:${dest} finished successfully"
        fi

    done

    return 0
}



#==============================================================================
# Initialize
#==============================================================================

# load user configuration by parsing file
parse_conf "$conf_file"

# remove quotes
backup_host=$(sed -e 's/^"//' -e 's/"$//' <<<"$backup_host")

if [ ! -d $bup_dir ] ; then
    mkdir $bup_dir
fi


last_bup=0
if [ -e $timestamp_file ] ; then
    last_bup=`cat $timestamp_file`
fi

current_time=`date +"%s"`
S=$(( $current_time -$last_bup ))
H=$(($S/3600))


#==============================================================================
# Check
#==============================================================================

# outdated backup?
if [ $H -lt $backup_interval ]; then

    log -dbg "Not yet time to run!"
    exit 0
fi

# is destination available?
ping -c 1 $backup_host &>/dev/null
if [ $? != 0 ]; then

    log -dbg "Destination ${backup_host} is not accessible"

    exit 0
fi

# try to lock, i.e. make sure no other instance is running
if ( mkdir $lockdir ) &> /dev/null ; then
    echo $$ > $lockpidfile
    trap 'rm -rf "$lockdir"; exit $?' INT TERM EXIT
else
    log -dbg "$lockdir exists, another instance is running"
    exit 0
fi


# we're ready to run, ask user for permission:

zenity --timeout 10 --title='BUP' --question --text="Backup is ready to run, do you wish to continue?" &>/dev/null
status=$?
if [ $status != 0 ]; then
    if [ $status == 1 ]; then
        log -dbg "User declined confirmation"
    elif [ $status == 5 ] ; then
        log -dbg "Confirmation dialog timed out"
    else
        log -dbg "Unknown dialog error"
    fi

    # clean up and exit
    rm -rf "$lockdir"
    trap - INT TERM EXIT
    exit 0
fi


#==============================================================================
# perform backup
#==============================================================================

run_backups

if [ $? != 0 ] ; then

    log "Backup failed!"
    rm -rf "$lockdir"
    trap - INT TERM EXIT
    exit 0
fi

notify-send 'BUP' 'Backup completed successfully' --icon=appointment-soon

echo ${current_time} > ${timestamp_file}
log "Backup completed successfully"

rm -rf "$lockdir"
trap - INT TERM EXIT
exit 0
