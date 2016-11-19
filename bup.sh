#!/bin/bash
#
# @author Karl Ljungkvist


BUP_PROG="rsync -zavh --delete --progress"

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

BUP_HOST=nas
BUP_ROOT="${BUP_HOST}:/volume1/backup"

EXCL="--exclude .cache
      --exclude .thumbnails
      --exclude .macromedia
      --exclude .local/share/Trash
      --exclude Media/Music
      --exclude Media/Pictures
      --exclude Downloads
      --exclude .Private
      --exclude Private/.thunderbird/q0nmltqo.default/ImapMail"


PREV_LINK="$BUP_ROOT/previous"
BUP_DST="$BUP_ROOT/current"

MUSIC_DST="${nas}:/volume1/music"
MUSIC_DST="${nas}:/volume1/photo"


### Stuff that goes into the backup directory



$BUP_PROG  -H --link-dest="$PREV_LINK/kalle" $EXCL /home/kalle/ "$BUP_DST/kalle"
check_for_error "Backup failed for copying home directory"

$BUP_PROG  /etc/            "$BUP_DST/etc"
check_for_error "Backup failed for copying /etc"

# $BUP_PROG  /usr/local/bin/  "$BUP_DST/usr_local_bin"
# check_for_error "Backup failed for copying /usr/local/bin"

# $BUP_PROG /usr/share/i18n/locales/en_SE "$BUP_DST"
# check_for_error "Backup failed for copying custom locale"

PKGLIST=`tmpfile`
dpkg -l | grep '^ii' | \awk '{print $2}' | sort > ${PKGLIST}
$BUP_PROG ${PKGLIST} "$BUP_DST/package_list"
check_for_error "Backup failed for copying package list"
rm ${PKGLIST}


### Media
$BUP_PROG "/home/kalle/Media/Pictures/" "${PHOTO_DEST}"
check_for_error "Backup failed for copying photos"

$BUP_PROG "/home/kalle/Media/Music/" "${MUSIC_DEST}"
check_for_error "Backup failed for copying music"
