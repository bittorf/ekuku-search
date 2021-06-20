#!/bin/sh
#
# this runs as 'root' and awaits commands from 'rexxbot3.sh' in
# file 'rexxbox-mountjob.txt' - we sanitize the input and run it regulary
#
# TODO!
# apt-get install inotify-tools

log()
{
	>&2 printf '%s\n' "$1"
}

mktemp_get_prefix()
{
	# e.g. /tmp/tmp.JBNSIHMii8 -> /tmp/tmp
	mktemp -u | cut -d'.' -f1
}

test "$( id -u )" -eq 0 || {
	log "[ERROR] must run as superuser"
	exit 1
}

alias explode='set -f;set +f --'

while true; do {
	sleep 1
	# directory-name build from 'unbox_container-mode' - see scan_dir() in file 'rexxbot3.sh'
	for JOBFILE in "$( mktemp_get_prefix )"*/rexxbot-mountjob.txt; do {
		read -r LINE 2>/dev/null <"$JOBFILE" || continue

		# shellcheck disable=SC2086
		explode $LINE

		# e.g. mount   /my/file.iso /this/dir iso9660
		# e.g. unmount /my/file.iso /this/dir
		ACTION="$1"		# mount|unmount|done
		CONTAINER="$2"		# filename
		MOUNTDIR="$3"		# dirname
		FSTYPE="${4:-auto}"	# https://askubuntu.com/questions/143718/mount-you-must-specify-the-filesystem-type

		[ "$ACTION" = 'done' ] || {
			log "file: $JOBFILE | line: $LINE"
			test -f "$CONTAINER" || ACTION='fail'
			test -d "$MOUNTDIR"  || ACTION='fail'
		}

		case "$ACTION" in
			'done')
			;;
			'mount')
				echo 'done' >"$JOBFILE"
				grep -q "$FSTYPE"$ /proc/filesystems && \
					mount -t "$FSTYPE" -o loop,user "$CONTAINER" "$MOUNTDIR" 2>/dev/null
			;;
			'unmount')
				echo 'done' >"$JOBFILE"
				mount | grep -q ^"$CONTAINER on $MOUNTDIR type" && \
					umount "$MOUNTDIR"
			;;
			*)
				log "ACTION: $ACTION LINE: $LINE"
			;;
		esac
	} done
} done
