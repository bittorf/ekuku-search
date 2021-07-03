#!/bin/sh

ARG1="$1"	# e.g. directory or 'query' or 'testsuite'
ARG2="$2"	# in query-mode or testsuite-mode: pattern

ARG1="testdir"
#ARG2="datei-untertitel-srt"	# for debugging: only extract 1 specific 'file'
#ARG2='TGZ-201900788.iso'

TMPDIR='/tmp'
SCRIPTDIR="$( CDPATH='' cd -- "$( dirname -- "$0" )" && pwd -P )"
case "$*" in *'--debug'*) DEBUG=1 ;; esac

alias explode='set -f;set +f --'

abort()
{
	echo "[ERROR] $*"
	exit 1
}

check_deps()
{
	:
	# file: https://github.com/file/file
	# ./configure --libdir=/usr/lib/x86_64-linux-gnu
	# make && make install
}


command -v 'firejail' || abort "missing 'firejail'"

# ./rexxbot3.sh | mysql --user=root
# mysql --user=root <test.sql
# SQL: show table status from filebot...;


# TODO:
# - setup() muss einmal gut durchlaufen, ansonsten abbruch - check aller dependencies
# - irgendwie fragen an user absetzen, z.b.: passwort fuer archivXY?

# TODO: fingerprinting:
#       - gfx/vid: https://www.reddit.com/r/programming/comments/8elci/so_does_anyone_know_the_algorithm_behind_googles/
#       - gfx/vid: http://www.phash.org/support/
#       - gfx/vid: http://www.stonehenge.com/merlyn/LinuxMag/col50.html
#       - audio:   https://acoustid.org/chromaprint
# TODO: renaming/detecting TV/movie:
#       - https://www.filebot.net/
# TODO: speech recognition:
#       - https://github.com/mozilla/DeepSpeech
#       - https://auphonic.com/blog/2016/08/16/speech-recognition-private-beta/
#       - https://github.com/Uberi/speech_recognition
# TODO: gzip + zip: https://github.com/BurntSushi/ripgrep/pull/305
# TODO: unace: unace-nonfree ODER https://github.com/droe/acefile
# TODO: video-playlength: ffmpeg -i input.mp4 -an -f null -
# TODO: OCR: ocropy and/or tesseract + http://waifu2x.udp.jp/
#       - http://blog.troyshu.com/2017/01/31/creating-a-stock-market-sentiment-twitter-bot-with-automated-image-processing/
#       - http://redpanda.nl/Tesseract/
#       - "k-means" image clustering
#       - http://ocrapiservice.com/documentation/
#       - https://github.com/tberg12/ocular
#       - https://news.ycombinator.com/item?id=8339609
#       - https://cloud.google.com/vision/
# TODO: https://github.com/cawel/subtitles-validator | http://subcheck.sourceforge.net/ | WebVTT | https://en.wikipedia.org/wiki/Subtitle_(captioning)
# TODO: mediainfo: https://mediaarea.net/en/MediaInfo/Support/Formats -> no! better use ffmpeg/sox
# TODO: movie/category: https://www.fandor.com/movie-genres/science-fiction-films-155
# TODO: fulltext: detect language
# TODO: how to detect if a directory/file was deleted? check all dirs/files regulary?
# TODO: utf8++
# TODO: marker for 'tried to unpack' or 'ready unpacked'
# TODO: implement .gz and .tar
# TODO: on 'query' show complete path
# TODO: better testfolder
#       e.g. https://www.virustotal.com/#/file/7871204f2832681c8ead96c9d509cd5874ed38bcfc6629cbc45472b9f388e09c/detection

mktemp_get_prefix()
{
	# e.g. /tmp/tmp.JBNSIHMii8 -> /tmp/tmp
	mktemp -u | cut -d'.' -f1
}

MKTEMPDIR="$( mktemp_get_prefix )"

log()
{
	local message="$1"
	local prio="$2"		# e.g. debug

	test -z "$DEBUG" -a "$prio" = 'debug' && return 0
	logger -s -- "$0: $message"
}

sandbox()
{
	local max_filesize="$1"
	local rc=0
	local params

	[ ${max_filesize:-0} -lt 1000000 ] && max_filesize=1000000
	max_filesize=$(( max_filesize * 2 ))

	shift
	params="--quiet --shell=/bin/sh --rlimit-fsize=$max_filesize"
	log "[OK] sandboxed_run: firejail $params $*"
	firejail $params "$@" || {
		rc=$?
		log "[ERROR] sandbox() rc: $rc"
		return $rc
	}
}

check_deps()
{
	:
	# base64
	# sha256sum
	# GNUfind
	# losetop or at least support for 'loop'-devices
	# mkfs.ext2
	# mysql-server
	# poppler-utils -> pdfdetach, pdftotext, pdfimages 
	# unzip
	# closure-linter (javascript) - gjslint --max_line_length 1 rexxbot3.sh >/dev/null

	# opkg --force-overwrite install findutils-find
	# opkg install coreutils-base64
}

check_dependencies()
{
	if [ "$( echo 'check_dependencies' | base64 -w0 )" = 'Y2hlY2tfZGVwZW5kZW5jaWVzCg==' ]; then
		[ "$( echo 'Y2hlY2tfZGVwZW5kZW5jaWVzCg==' | base64 -d )" = 'check_dependencies' ] || {
			log "please install base64 - check: base64 -d"
		}
	else
		log "please install base64 - check: base64 -w0"
		return 1
	fi

	command -v 'gjslint' >/dev/null || {
		log "missing 'gjslint' - try package: closure-linter"
		return 1
	}

	pidof mysqld >/dev/null || {
		log "[ERROR] mysql-server is not running"
		return 1
	}

	true
}

file_detect_magic()
{
	local file="$1"
	local binary='/home/bastian/software/file-magic/file/src/fileX'
	local magic='/usr/local/share/misc/magic.mgc'

	# fallback to normal path, e.g. /usr/bin/file
	[ -x "$binary" ] || binary='file'

	# sourcecode at:
	# http://www.darwinsys.com/file/
	# https://github.com/file/file

	if [ -e "$magic" ]; then
		MAGIC=$magic $binary -b --mime-type "$file"
	else
		             $binary -b --mime-type "$file"
	fi
}

db()
{
	local action="$1"	# add
	log "action: $action"

	# design:
	# http://stackoverflow.com/questions/3070384/how-to-store-a-list-in-a-column-of-a-database-table
	# http://stackoverflow.com/questions/14677288/how-to-make-a-field-in-a-table-reference-to-another-table-in-mysql-mariadb
	# http://stackoverflow.com/questions/10628186/mysql-store-multiple-references-for-another-table-inside-one-cell-and-select-it
	# http://stackoverflow.com/questions/144344/how-to-store-directory-hierarchy-tree-structure-in-the-database
	# https://github.com/clyfe/acts_as_nested_interval
	# https://github.com/stefankroes/ancestry -> Navigating your tree
	# http://stackoverflow.com/questions/2797720/sorting-tree-with-a-materialized-path
	# http://dirtsimple.org/2010/11/simplest-way-to-do-tree-based-queries.html
	# http://stackoverflow.com/questions/3362669/what-are-the-known-ways-to-store-a-tree-structure-in-a-relational-db
	# https://www.php.de/forum/webentwicklung/datenbanken/107119-baumstruktur-nested-sets-oder-closure-table
	# http://www.webmastersdiary.de/blog/hierarchie-baum-in-hierarchischer-mysql-tabelle-mit-einem-query-abfragen/
	# http://troels.arvin.dk/db/rdbms/links/#hierarchical
	# https://github.com/developerworks/hierarchy-data-closure-table


	# search-as-you-type (SAYT)
	# http://uxzentrisch.de/search-as-you-type-suche-regeln/
	# https://en.wikipedia.org/wiki/Incremental_search
	# http://stackoverflow.com/questions/4948605/googles-predictive-text-as-you-type-code-example-w-o-auto-suggest-dropdown-me
	# http://stackoverflow.com/questions/9426254/how-to-implement-faster-search-as-you-type-sayt-api-in-rails-3-application
	# http://stackoverflow.com/questions/759580/how-to-implement-a-keyword-search-in-mysql

	# C64-examples:
	# http://cbmfiles.com/genie/HiResGraphicsListing.php
	# https://github.com/jkotlinski/vicpack

	# MIME-type: https://de.wikipedia.org/wiki/Internet_Media_Type
	# https://en.wikipedia.org/wiki/File_(command)
	# - http://mx.gw.com/pipermail/file/2016/002213.html
	# - https://github.com/file/file

	# table:main
	# lfd.ID dirname filename/lastpart dir/file/arc/type size reference? mime?filetype ctime file_hash ID-from-meta-table name_meta_table

	# http://www.elated.com/articles/mysql-for-absolute-beginners/

:'
	show tables;
	explain files;

	INSERT INTO books ( title, author, price )
		VALUES ( "", "", "" );

	DROP TABLE IF EXISTS meta.audio
	CREATE TABLE meta.audio
'

	# table:meta.audio
	# lfd.ID + size + hash + playlength + channels + bitrate + quali + (music/interview+mood?) + fulltext or lyrics?

	# table:meta.gfx
	# lfd.ID + size + hash + ID.main + resolutionX + resolutionY + depth + quali + (photo/clipart/painting) + fulltext
	# liste von gegenstaenden?
	# gesichts-ID's?

	# table:movie
	# lfd.ID + size + hash + playlength + Vcodec + Acodec + imdb + YEAR/REGISSEUR/GENRE? + fulltext + quali
	# - split into audio/video-entry like an archive!

	# table:pdf
	# - split into different files (e.g. pictures, audio, text)

	# table:binwalk...


	# metadata (audio, video, gfx, txt)
	# - quality
	# - format/container (e.g. jpeg, matroska, koala, openoffice)
	# - subformat: audio-format, videoformat?
	# - playlength: video/audio
	# - dimension (e.g. 3400x9000x16bit)
	# - imdb?
	#   - regisseur?
	# - who is on pic? persion-ID's
	# - text in pictures + fulltext
}

db_init()
{
	cat <<EOF
DROP DATABASE IF EXISTS filebot;
create database filebot;
USE filebot;

DROP TABLE IF EXISTS files;
CREATE TABLE files
(
	id	int unsigned NOT NULL auto_increment,

	file	varchar(255) NOT NULL,
	dirID	int unsigned NOT NULL,
	type	char(1) NOT NULL,		/* f = file, a = archive? */
	size	decimal(32) NOT NULL,
	ctime	decimal(32) NOT NULL,
	mime	varchar(255) NOT NULL,
	sha256	varchar(64) NOT NULL,

	metaTAB	varchar(32) NOT NULL,		/* name, e.g. audio */
	metaID	int unsigned NOT NULL,		/* ... */
	ref	int unsigned NOT NULL,		/* closure table? unused... */

	PRIMARY KEY     (id)
);

DROP TABLE IF EXISTS dirs;
CREATE TABLE dirs
(
	id	int unsigned NOT NULL auto_increment,
	dir	varchar(32768) NOT NULL,
	PRIMARY KEY	(id)			/* or better = dir? */
);

EOF
}

db_insert_file()
{
	cat <<EOF
INSERT IGNORE INTO files
	( file, dirID, type, size, ctime, mime, sha256, metatab, metaID, ref )
	VALUES ( "$1", (SELECT id FROM dirs WHERE dir = "$2") , "$3", "$4", "$5", "$6", "$7", "$8", "$9", "${10}" );

EOF

	# id FROM player WHERE uniqueDeviceId = 123;
}

db_insert_dir()
{
	cat <<EOF
INSERT IGNORE INTO dirs
	( dir )
	VALUES ( "$1" );

EOF
}

virtual_limited_partition()
{
	# TODO:
	# start a "daemon" which
	# - accepts "creating/deleting a loop-device size-limited" under /tmp/rexxbot/... (give random token?)
	# - destroys it including removing file (with token)
	# so we can unpack as user without to fear a zip-bomb

	# 1) scan files...
	# 2) write the easy things into DB including the skeleton of meta
	# 3) another loops looks into DB and jobs the unfished archives...

	# TODO: useable also for https://wiki.ubuntuusers.de/CD-Images/
	#  ISO-images? mount -o loop /home/BENUTZERNAME/image.iso /mnt/temp 
	#  .cue? nrg = nero?

	# TODO:
	# avoid code-duplication when mounting e.g. 'iso'-images?

	local funcname='virtual_limited_partition'
	local action="$1"	# start|stop
	local size="$2"		# [megabytes] -> look into archive_list() -> exspected_size
	local reason="$3"	# must be the same for start|stop and uniq
	local file="$TMPDIR/$funcname.$reason.bin"
	local mount_dir="$file.mounted"

	if [ "$( id -u )" = '0' ]; then
		log "[OK] creating loop-device with $size mb for '$reason'"
	else
		log "[ERR] $funcname() must be root"
		return 1
	fi

	if dd 'if=/dev/zero' "of=$file" 'bs=1M' "count=$size"; then	# non-root-user can do this!
		if mkfs.ext2 -F "$file"; then				# this too!
			if mkdir "$mount_dir"; then			# this too!
				if mount -o loop,user "$file" "$mount_dir"; then
					echo "$mount_dir"
				else
					log "[ERR] $funcname() mount -o loop,user '$file' '$mount_dir', rc:$?"
				fi
			else
				log "[ERR] $funcname() mkdir '$file', rc:$?"
			fi
		else
			log "[ERR] $funcname() mkfs.ext2 -F '$file', rc:$?"
		fi
	else
		log "[ERR] $funcname() creating '$file' of size $size MB failed, rc:$?"
		rm "$file" || log "[ERR] $funcname() rm '$file', rc:$?"

		return 1
	fi
}

file_hash()
{
	local file="$1"

	if [ -s "$file" ]; then
		sha256sum "$file" | cut -d' ' -f1
	else
		echo '0'	# does not make sense for 0-byte files
	fi
}

get_new_tempdir()
{
	local dir

	# http://unix.stackexchange.com/questions/30091/fix-or-alternative-for-mktemp-in-os-x
	# e.g. '/tmp/tmp.Nv80niuepS'
	dir="$( mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir' )"

	echo "$dir" >>"$TMPDIR/tmpdir_list.txt"
	echo "$dir"
}

remove_tmpdir()
{
	local dir
	local file="$TMPDIR/tmpdir_list.txt"

	while read -r dir; do {
		test -d "$dir" && {
			log "rm -fR \"$dir\""
			rm -fR "$dir"
		}
	} done <"$file"

	rm "$file"
}

file_is_javascript()		# deps: node
{
	local file="$1"
	local copy rc

	copy="$( mktemp --suffix=.js )" || return 1

	node --check "$copy" 2>/dev/null
	rc=$?
	rm -f "$copy"

	test $rc -eq 0
}

file_is_makefile()
{
	local file="$1"

	make -d -i --dry-run -f "$file" >/dev/null 2>/dev/null
}

movie_count_frames()
{
	local file="$1"
	local stream_id=0		# TODO: search file with >1 stream

	# TODO: count first 5 seconds + extrapolate?
	# # https://stackoverflow.com/questions/2017843/fetch-frame-count-with-ffmpeg
	ffprobe -v error \
		-count_frames \
		-select_streams v:$stream_id \
		-show_entries stream=nb_read_frames \
		-of default=nokey=1:noprint_wrappers=1 \
			"$file"
}

mimetype_get()
{
	local file="$1"
	local mime

	mime="$( file_detect_magic "$file" )"

	case "$mime" in
		'text/plain')
			if   file_is_javascript "$file"; then
				mime='application/javascript'
			elif file_is_makefile "$file"; then
				mime='text/x-makefile'
			fi
		;;
	esac

	log "mimetype_get() $mime | file: '$file'" debug
	echo "$mime"
}

output_first_1000bytes_without_ascii_art()
{
	local file="$1"
	local line word word_without_duplicates bytes=0
	local buffer=
	local buffer_all=
	local parse=

	while read -r line; do {
		for word in $line; do {
			buffer_all="$buffer_all $word"

			word_without_duplicates="$( echo "$word" | sed 's/\(.\)\1/\1/g' )"
			[ "$word" = "$word_without_duplicates" ] || continue

			case "$parse" in
				'')

					test ${#word} -ge 8 && parse='true'
				;;
			esac

			[ ${#word} -gt 3 ] && [ -n "$parse" ] && {
				bytes=$(( bytes + ${#word} ))
				[ $bytes -ge 1000 ] && break
				printf '%s' "$word "
				buffer="$buffer $word"		# only debug
			}
		} done
	} done <"$file"

	log "[OK] output_first_1000bytes_without_ascii_art: $bytes" debug
	log "[OK] buffer1: '$buffer'" debug
	log "[OK] buffer2: '$buffer_all'" debug

	true
}

check_lang()
{
	local text="$1"
	local script='experiments/guess_language/check_language.py'

	# https://bitbucket.org/spirit/guess_language
	# https://stackoverflow.com/questions/3227524/how-to-detect-language-of-user-entered-text
	$script "$text"
}

extract_metadata_text_plain()
{
	local file="$1"
	local option="$2"

	local version=1
	local lang buffer

	case "$option" in
		'expected_vars')
			printf '%s' 'VERSION LANGUAGE'
		;;
		*)
			buffer="$( output_first_1000bytes_without_ascii_art "$file" )"
			lang="$( check_lang "$buffer" )"

			export VERSION="$version"
			export LANGUAGE="$lang"
		;;
	esac
}

extract_metadata_image_jpeg()		# TODO: https://rfc1149.net/devel/recoverjpeg.html
{
	local file="$1"
	local option="$2"

	local version=1
	local format exif_datetime exif_gpslat exif_gpslon width height depth cameramodel

	format='exif_datetime="%[EXIF:DateTime]";exif_gpslat="%[EXIF:GPSLatitude]";exif_gpslon="%[EXIF:GPSLongitude]"'
	format="$format;width=%[width];height=%[height];depth=%[depth];cameramodel=\"%[EXIF:Model]\""

	# TODO: https://stackoverflow.com/questions/19804768/interpreting-gps-info-of-exif-data-from-photo-in-python
	# TODO: https://stackoverflow.com/questions/5857820/how-to-get-camera-serial-number-from-exif

	case "$option" in
		'expected_vars')
			printf '%s' 'VERSION EXIF_DATETIME EXIF_GPSLAT EXIF_GPSLON WIDTH HEIGHT DEPTH CAMERAMODEL'
		;;
		*)
			# TODO: LAT LON ALTITUDE 50.9902585 11.3306255 0
			# GPSLatitude=50/1, 58/1, 575701/10000
			# GPSLongitude=11/1, 19/1, 189271/10000

			# debug: identify -format '%[EXIF:*]' image.jpg
			# shellcheck disable=SC2046
			eval $( identify -format "$format" "$file" 2>/dev/null )

			export VERSION="$version"
			export EXIF_DATETIME="$exif_datetime"
			export EXIF_GPSLAT="$exif_gpslat"
			export EXIF_GPSLON="$exif_gpslon"
			export WIDTH="$width"
			export HEIGHT="$height"
			export DEPTH="$depth"
			export CAMERAMODEL="$cameramodel"
		;;
	esac
}

extract_metadata_image_simple()
{
	local file="$1"
	local option="$2"

	local version=1
	local format width height depth

	case "$option" in
		'expected_vars')
			printf '%s' 'VERSION WIDTH HEIGHT DEPTH'
		;;
		*)
			format="width=%[width];height=%[height];depth=%[depth]"

			# shellcheck disable=SC2046
			eval $( identify -format "$format" "$file" 2>/dev/null )

			export VERSION="$version"
			export WIDTH="$width"
			export HEIGHT="$height"
			export DEPTH="$depth"
		;;
	esac
}

extract_metadata_audio()
{
	local file="$1"
	local option="$2"

	local version=1
	local format='codec_name,sample_rate,channels,bits_per_sample,duration'
	local codec_name sample_rate channels bits_per_sample duration

	case "$option" in
		'expected_vars')
			printf '%s' 'VERSION CODEC SAMPLE_RATE CHANNELS BITS_PER_SAMPLE DURATION'
		;;
		*)
			# debug: ffprobe -v quiet -print_format json -show_format -show_streams FILE

			# [STREAM]
			# codec_name=aac
			# sample_rate=44100
			# channels=2
			# bits_per_sample=0
			# duration=12098.728024
			# [/STREAM]

			# shellcheck disable=SC2046
			eval $( ffprobe -v error -show_entries stream="$format" "$file" | grep -v 'STREAM]'$ )

			# TODO: fix upstream bug
			[ "$bits_per_sample" = '0' ] && bits_per_sample=16

			export VERSION="$version"
			export CODEC="$codec_name"
			export SAMPLE_RATE="$sample_rate"
			export CHANNELS="$channels"
			export BITS_PER_SAMPLE="$bits_per_sample"
			export DURATION="${duration%.*}"		# cut off/ignore fractions of a second
		;;
	esac
}

extract_metadata()	# we can only extract from a non-container-file, e.g. a PDF is a container
{
	local file="$1"		# can be <empty> when option='expected_vars'
	local mime="$2"
	local option="$3"	# <empty> or 'expected_vars'

	case "$mime" in
		'image/'*)
#			[ -z "$option" ] && feh "$file"
		;;
	esac

	case "$mime" in
		'text/xml')
			:
		;;
		'message/rfc822')
			extract_metadata_text_plain "$file" "$option"	# FIXME!
		;;
		'text/plain')
			extract_metadata_text_plain "$file" "$option"
		;;
		'image/jpeg')
			extract_metadata_image_jpeg "$file" "$option"
		;;
		'image/x-portable-pixmap'|'image/png'|'image/webp'|'image/gif')
			extract_metadata_image_simple "$file" "$option"
		;;
		'audio/x-wav'|'audio/x-hx-aac-adts')
			extract_metadata_audio "$file" "$option"
		;;
		'audio/mpeg')
			extract_metadata_audio "$file" "$option"	# TODO: extract images?
		;;
		'application/javascript'|'application/octet-stream')
			:
		;;
		'text/x-perl'|'text/x-shellscript'|'text/x-makefile')
			:
		;;
		'inode/x-empty')
			:
		;;
		'application/x-mach-binary')
			:
		;;
		'application/x-dosexec')
			[ -f "$file" ] && {
				cp -v "$file" /tmp/debug.bin
				chmod 777 /tmp/debug.bin

				log "TODO: https://developers.virustotal.com/reference#file-report"
			}

			true
		;;
		*)
			log "[...] mime '$mime' not implemented yet"
			return 1
		;;
	esac

	true
}

already_deep_scanned()
{
	# TODO: needs database lookup, e.g. with plugin-versions last used
	false
}

scan_dir()
{
	local dir="$1"
	local parent="$2"	# used when unboxing container: TODO: rewrite in database (e.g. archiv.tgz looks like dir)
	local option="$3"	# e.g. search pattern for DEBUGGING

	local linecount d=0 f=0	# counters
	local file working_dir line chksum mime container_dir tempfile size ctime varname list value

#	local dirname sha256
#	local reference=	# e.g. archiv.tar -> size + hash
#	local path='/foo/bar'	# !! can have spaces and newlines
#	local name='this name'	# !! can have spaces and newlines
#	local filetype='f'	# = file or 'd' = dir or 'a' = archive or 'c' = container?

	tempfile="$( get_new_tempdir )/temp_$$"

	if [ -d "$dir" ]; then
		# remove trailing '/' if any:
		case "$dir" in *'/') dir="${dir%?}" ;; esac

		# http://stackoverflow.com/questions/1116992/capturing-output-of-find-print0-into-a-bash-array
		# https://stackoverflow.com/questions/4321456/find-exec-a-shell-function-in-linux
		log "[OK] start crawling dir '$dir'"
		if [ -n "$option" ]; then
			find "$dir" -xdev -ipath "*$option*" -exec "$SCRIPTDIR/rexxbot3-string-to-base64.sh" '{}' \; >"$tempfile"
		else
			find "$dir" -xdev                    -exec "$SCRIPTDIR/rexxbot3-string-to-base64.sh" '{}' \; >"$tempfile"
		fi
		linecount="$( wc -l <"$tempfile" )"
		log "[OK] ready crawling dir '$dir' ($linecount entries) - now building chksums and more"
	else
		log "[ERROR] dir not found: '$dir'"
		return 1
	fi

	while read -r line; do {
		file="$( printf '%s' "$line" | base64 -d )"

		if   [ -d "$file" ]; then
			d=$(( d + 1 ))

			working_dir="$file"
			log "[OK] scan_dir() DIR: '$working_dir' parent: '$parent'"

#			db_insert_dir "$working_dir"
		elif [ -f "$file" ]; then
			f=$(( f + 1 ))

			fname="$( basename -- "$file" )"
			size="$( stat --printf="%s" "$file" )"		# bytes
			chksum="$( file_hash "$file" )"			# 64 bytes

			# TODO: first lookup DB and only scan deeper if not in DB yet?

			dname="$( dirname "$file" )"
			ctime="$( date +%s -r "$file" )"
			mime="$( mimetype_get "$file" )"		# e.g. 'application/pdf'

			# TODO: check if already in DB
			if [ -n "$parent" ]; then
				log "[OK] scan_dir() FILE: '$fname' mime: '$mime' dname: '$dname' parent: '$parent'"
#				db_insert_file "$fname" "$parent" 'a' "$size" "$ctime" "$mime" "$chksum"
			else
				log "[OK] scan_dir() FILE: '$fname' mime: '$mime'"
#				db_insert_file "$fname" "$dname" 'f' "$size" "$ctime" "$mime" "$chksum"
			fi

			if   already_deep_scanned "$chksum"; then
				:
			elif unbox_container "$file" "$mime" 'check_if_supported'; then
				if container_dir="$( unbox_container "$file" "$mime" )"; then
					scan_dir "$container_dir" "$dir/$fname" ''
				else
					log "[ERROR] unbox_container went wrong: container_dir: '$container_dir' file '$file'"
				fi
			else
				if extract_metadata "$file" "$mime"; then
					list="$( extract_metadata '' "$mime" 'expected_vars' )"

					for varname in file ctime $list; do {
						eval value="\${$varname}"
						log "[OK] --meta: $varname = $value"
					} done

					log "[OK] $( extract_metadata '' "$mime" 'expected_vars' ) - ctime: $ctime"
				else
					log "[ERROR] extract_metadata failed"
				fi
			fi
		else
			log "[OK] cannot find '$file' from '$line'"		# e.g. dead symlink
		fi
	} done <"$tempfile"
	rm -fR "$( dirname "$tempfile" )"

	# in unbox_container-mode: delete unpacked dir after scan ready
	if [ -n "$parent" ] && [ -d "$dir" ]; then
		case "$dir" in
			"$MKTEMPDIR"*)
				log "[OK] removing container-dir: '$dir'"

				case "$dir" in
					*'/mountdir')
						DIRNAME="$( dirname "$dir" )"
						CONTAINER="$( readlink "$DIRNAME/symlinked_file" )"
						JOB="$DIRNAME/rexxbot-mountjob.txt"

						[ -f "$JOB" ] && {
							echo >"$JOB" "unmount $CONTAINER $dir"
							wait_till_tried_mountaction "$JOB"
							dir="$DIRNAME"
						}
					;;
				esac

				rm -fR "$dir" || log "[ERROR] rm -fR '$dir'"
			;;
			*)
				log "[ERROR] wrong dir '$dir' - THIS SHOULD NEVER HAPPEN"
				exit 128
			;;
		esac
	else
		:
		log "[OK] ignoring: parent: '$parent' dir: '$dir'"
	fi

	log "[OK] scan_dir() dir: '$dir' parent: '$parent' count: $f files in $d dirs"
}

wait_till_tried_mountaction()	# see: rexxbot3-mountiso-superuser.sh
{
	local jobfile="$1"

	while true; do {
		grep -q ^'done' "$jobfile" && break

		sleep 5
		log "[OK] waiting: $jobfile"
	} done
}

unbox_container()		# TODO: make sure we never emit trash to STDOUT, because that is our returncode
{
	local file="$1"
	local mime="$2"
	local support="$3"	# <empty> or 'check_if_supported'
	local tempdir estimated_bytes file_basename line word
	local rc=0

	if   [ -f "$PWD/$file" ]; then
		file="$PWD/$file"
	elif [ -f "$file" ]; then
		:
	else
		log "[ERROR] unbox_container() - file not found: '$file'"
		return 1
	fi

	file_basename="$( basename -- "$file" )"

	check()
	{
		if [ "$1" = 'check_if_supported' ]; then
			return 0
		else
			log "[OK] is '$mime', going into container '$file'"
			tempdir="$( get_new_tempdir )"
			return 1
		fi
	}

	# TODO: handle errors, e.g. autodelete?
	# TODO: only shorten names, better do not append things?
	case "$mime" in
		'text/troff')
			check "$support" && return

			# https://de.wikipedia.org/wiki/Troff
			sandbox 1 man "$file" | col -b >"$tempdir/out.txt"
		;;
		'application/x-iso9660-image')
			check "$support" && return

			ln -s "$file" "$tempdir/symlinked_file"		# this works also with strange filenames
			mkdir "$tempdir/mountdir"

			echo >"$tempdir/rexxbot-mountjob.txt" "mount $tempdir/symlinked_file $tempdir/mountdir iso9660"
			wait_till_tried_mountaction "$tempdir/rexxbot-mountjob.txt"

			tempdir="$tempdir/mountdir"
		;;
		'application/gzip'|'application/x-gzip')
			check "$support" && return

			# shellcheck disable=SC2046
			explode $( gzip -l "$file" | tail -n1 )
			estimated_bytes="$2"
			log "[OK] $mime: expected_uncompressed: $estimated_bytes bytes - '$file'"

			sandbox "$estimated_bytes" gzip -d -c "$file" >"$tempdir/${file_basename}.unpacked"
		;;
		'application/x-tar')			# FIXME: sandbox
			check "$support" && return

			tar -C "$tempdir" -xf "$file"
		;;
		'application/x-rar')
			check "$support" && return

			# https://github.com/netblue30/firejail/issues/1632
			# unrar-nonfree = unrar (but symlinking confuses sandbox)

			# shellcheck disable=SC2046
			explode $( sandbox 1 unrar-nonfree l "$file" | grep -A1 -- ^'-----------' | tail -n1 )
			estimated_bytes="$1"
			log "[OK] $mime: expected_uncompressed: $estimated_bytes bytes - '$file'"

			# switch -w (workingdir) seems not reliable, so we have to work around
			# we always give a password FOO, this does not affect passwordless archives
			# and we have no interactive questions
			cd "$tempdir" || return 1
			sandbox "$estimated_bytes" unrar-nonfree x -y -pFOO "$file" >/dev/null || rc=$?
			cd - >/dev/null || return 1
		;;
		'application/zip'|'application/x-7z-compressed')
			check "$support" && return

			# e.g. 2016-03-24 10:33:06  51356281  27764261  195 files, 1 folders
			# shellcheck disable=SC2046
			explode $( sandbox 1 7z l "$file" | tail -n1 )
			estimated_bytes="$3"
			log "[OK] $mime: expected_uncompressed: $estimated_bytes bytes - '$file'"

			# switch -w (workingdir) seems not reliable, so we have to work around
			# we always give a password FOO, this does not affect passwordless archives
			# and we have no interactive questions
			cd "$tempdir" || return 1
			sandbox "$estimated_bytes" 7z x -y -pFOO "$file" >/dev/null || rc=$?
			cd - >/dev/null || return 1
		;;
		'application/pdf')			# FIXME: sandbox
			check "$support" && return

			# gets deleted later
			cp "$file" "$tempdir"

			cd "$tempdir" >/dev/null || return 1

			# poppler-utils:
			# extracts only images: output in different formats (png, jpeg, tiff ...)
			pdfimages -all "$file_basename" 'pdfimages' || log "[ERROR] pdfimages: $?"
			log "[OK] pdfimages: extracted $( find . -name 'pdfimages*' | wc -l ) images" debug

			# extracts plain text
			pdftotext -layout "$file_basename" 'pdf.txt' || log "[ERROR] pdftotext: $?"

			# extracts  embedded  files (attachments)
			pdfdetach -saveall "$file_basename" || log "[ERROR] pdfdetach: $?"

			# images - TODO: move to generate metadata - generate full view
			pdftoppm -q -png -rx 72 -ry 72 "$file_basename" "$tempdir/pdf2ppm" || log "[ERROR] pdftoppm: $?"
			log "[OK] pdf2ppm: extracted $( find "$tempdir" -name 'pdf2ppm*' | wc -l ) images" debug

			# original file not needed
			rm "$file_basename"

			cd - >/dev/null || return 1
		;;
		'text/rtf'|\
		'text/html'|\
		'application/msword'|\
		'application/vnd.openxmlformats-officedocument.wordprocessingml.document'|\
		'application/vnd.ms-excel'|\
		'application/vnd.ms-powerpoint'|\
		'application/vnd.oasis.opendocument.text')
			check "$support" && return

			# FIXME: sandbox

			sandbox 1 lowriter \
				--convert-to pdf:writer_pdf_Export \
				--outdir "$tempdir" \
				"$file" >/dev/null 2>/dev/null || log "[ERROR] lowriter: $? file: '$file'"
		;;
		'video/x-m4v')
			check "$support" && return

			# FIXME sandbox

			# [STREAM]
			# index=0
			# codec_name=aac
			# codec_type=audio
			# [/STREAM]
			#
			# [STREAM]
			# index=1
			# codec_name=bin_data
			# codec_type=data
			# [/STREAM]
			#
			# [STREAM]
			# index=2
			# codec_name=mjpeg
			# codec_type=video
			# [/STREAM]

			# extract everything:
			# https://stackoverflow.com/questions/32922226/extract-every-audio-and-subtitles-from-a-video-with-ffmpeg

			ffprobe -v error -show_entries stream='index,codec_name,codec_type' "$file" | while read -r line; do {
				case "$line" in
					'index='*)
						IDX="$( echo "$line" | cut -d'=' -f2 )"			# e.g. 0, 1, 2
					;;
					'codec_name='*)
						CODEC="$( echo "$line" | cut -d'=' -f2 )"		# e.g. aac, bin_data, mjpeg
					;;
					'codec_type='*)
						CODEC_TYPE="$( echo "$line" | cut -d'=' -f2 )"		# e.g. audio, data, video

						# https://trac.ffmpeg.org/ticket/7762
						[ "$CODEC" = 'bin_data' ] && continue

						ffmpeg -i "$file" -map "0:$IDX" -c copy "$tempdir/stream$IDX-$CODEC_TYPE.$CODEC"
					;;
				esac
			} done
		;;
		*)
			return 1
		;;
	esac

	[ $rc -eq 0 ] || log "[ERROR] unbox_container: rc $?"
	echo "$tempdir"
	return $rc
}

update_db_file()
{
	local dir="$1"
	local file="$2"

	:
}


#f="/home/bastian/sunwait-20041208.tar.gz"
#unpack_archive "$f" "application/gzip" "check_if_supported" && {
#	unpack_archive "$f" "application/gzip"
#}

#f="/tmp/tmp.bpNGlcmSQM/sunwait-20041208.tar.gz.unpacked"
#unpack_archive "$f" "application/x-tar" "check_if_supported" && {
#	unpack_archive "$f" "application/x-tar"
#}
#
#exit 0

case "$ARG1" in
	'query')
		if [ -n "$ARG2" ]; then
			# SUB="(SELECT dir FROM dirs WHERE id = '$2')"
			echo "USE filebot; SELECT mime,size,file FROM files WHERE file LIKE '%${ARG2}%';"
			echo "USE filebot; SELECT dir FROM dirs WHERE dir LIKE '%${ARG2}%';"
		else
			echo "show databases;"
			echo "USE filebot;"
			echo "SELECT CONCAT(' ');"
			echo "SELECT * from dirs;"
			echo "SELECT CONCAT(' ');"
			echo "SELECT * from files;"
		fi | mysql --skip-column-names --user=root
	;;
	'testsuite')
		testsuite
	;;
	*)
		db_init
		scan_dir "$ARG1" '' "$ARG2"
		remove_tmpdir
	;;
esac
