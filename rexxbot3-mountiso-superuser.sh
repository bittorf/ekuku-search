#!/bin/sh

# e.g. while :; do ./rexxbot3-mountiso-superuser.sh; sleep 1; done

mktemp_get_prefix()
{
	# e.g. /tmp/tmp.JBNSIHMii8 -> /tmp/tmp
	mktemp -u | cut -d'.' -f1
}

if [ "$( id -u )" = '0' ]; then
	RC=0
else
	RC=1
	logger -s "[ERROR] must run as superuser"
fi

alias explode='set -f;set +f --'

for JOBFILE in "$( mktemp_get_prefix )"*/mountjob.txt; do {
	[ -f "$JOBFILE" ] || continue

	read -r LINE <"$JOBFILE"

	# shellcheck disable=SC2086
	explode $LINE

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
		mount)
			mount -t "$FSTYPE" -o loop,user "$CONTAINER" "$MOUNTDIR" 2>/dev/null || RC=$?
			echo 'done' >"$JOBFILE"
		;;
		unmount)
			if mount | grep -q ^"$CONTAINER on $MOUNTDIR type"; then
				umount "$MOUNTDIR" || RC=$?
			else
				RC=1
			fi

			echo 'done' >"$JOBFILE"
		;;
		fail)
			logger -s "ACTION: $ACTION LINE: $LINE"
		;;
	esac
} done

test $RC -eq 0
