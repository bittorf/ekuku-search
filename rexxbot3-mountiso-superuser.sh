#!/bin/sh
#
# this runs as 'root' and awaits commands from 'rexxbot3.sh' in 'mountjob.txt'
# we sanitize the input and run it regulary, e.g.:
#
# while :; do ./rexxbot3-mountiso-superuser.sh; sleep 1; done

mktemp_get_prefix()
{
	# e.g. /tmp/tmp.JBNSIHMii8 -> /tmp/tmp
	mktemp -u | cut -d'.' -f1
}

alias explode='set -f;set +f --'

# directory-name build from 'unbox_container-mode' - see scan_dir() in file 'rexxbot3.sh'
for JOBFILE in "$( mktemp_get_prefix )"*/mountjob.txt; do {
	read -r LINE 2>/dev/null <"$JOBFILE" || continue
	case "$( id -u )" in 0) ;; *) logger -s "[ERROR] must run as superuser"; exit 1 ;; esac

	# shellcheck disable=SC2086
	explode $LINE

	# e.g. mount   /my/file.iso /this/dir iso9660
	# e.g. unmount /my/file.iso /this/dir
	ACTION="$1"		# mount|unmount|done
	CONTAINER="$2"		# filename
	MOUNTDIR="$3"		# dirname
	FSTYPE="${4:-auto}"	# https://askubuntu.com/questions/143718/mount-you-must-specify-the-filesystem-type
				# cat /proc/filesystems

	[ "$ACTION" = 'done' ] || {
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
			logger -s "ACTION: $ACTION LINE: $LINE"
		;;
	esac
} done
