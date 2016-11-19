#!/bin/bash
#
#
# @author Karl Ljungkvist


backup_dir="/volume1/backup/"

current="${backup_dir}/current"
previous="${backup_dir}/previous"

# rotate previous and current...
T=$(date +"%F")

new_name="${backup_dir}/backup-$T"

if [ -e "$new_name" ] ;
then
    ERROR! # (probably send an email...)
fi

mv "$current" "$new_name"

mkdir "$current"

ln -s -T "$new_name" "$previous"
