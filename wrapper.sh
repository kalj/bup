#!/bin/bash
#
# @author Karl Ljungkvist


#==============================================================================

# bup_prog="/home/kalle/code/bup/bup.sh"
# bup_prog="/home/kalle/code/bup/bup.sh -n"
# bup_prog="echo 'fake execution!'"


#==============================================================================

# internal files
conf_file=$HOME/.bupconf
bup_dir=$HOME/.bup
timestamp_file=${bup_dir}/stamp
lockdir=/tmp/bup-lock-dir
lockpidfile=/tmp/bup-lock-dir/pid

# logging
log_file=${bup_dir}/log
detailed_file=${bup_dir}/detailed

function log()
{
   if [ "$1" == "-dbg" ] ; then
       shift 1
       echo "DEBUG $(date +"%F %T"): $@" >>$detailed_file
   else
       echo "$@" | tee -a $detailed_file $log_file
   fi
}


#==============================================================================
# intialization
#==============================================================================


# load user configuration
loadconf $conf_file



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
# check
#==============================================================================

# outdated backup?
if [ $H -lt $bup_interval_hours ]; then

    log -dbg "Not yet time to run!"
    exit 0
fi

# is destination available?
ping -c 1 $destination_host &>/dev/null
if [ $? != 0 ]; then

    log -dbg "Destination ${destination_host} is not accessible"
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

zenity --timeout 5 --title='BUP' --question="Backup is ready to run, do you wish to continue?" &>/dev/null
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

$bup_prog &>> $detailed_file

if [ $? != 0 ] ; then

    log "$(date --date="@${current_time}" +"%F %T"): Backup failed!"
    rm -rf "$lockdir"
    trap - INT TERM EXIT
    exit 0
fi

notify-send 'BUP' 'Backup completed successfully' --icon=appointment-soon

echo ${current_time} > ${timestamp_file}
log "$(date --date="@${current_time}" +"%F %T"): Backup completed successfully"

rm -rf "$lockdir"
trap - INT TERM EXIT
exit 0
