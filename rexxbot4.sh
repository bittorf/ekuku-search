#!/bin/sh
# shellcheck shell=dash source=rexxbot-plugins/

ACTION="$1"
ARG1="$2"
ARG2="$3"	# empty or <debug>

usage()
{
	cat <<EOF

=== file_cabinet / rexxbot / ekukubot / filebot / ekuku-search ===

Usage:	$0 <action> <option1> <option2>

  e.g:	$0 fastscan /dir/to/scan <debug>

	$0 mimesha
	$0 table_drop
	$0 table_show
	$0 table_show_files
	$0 table_show_meta
	$0 atomic
	$0 mime <file>
	$0 deps missing_only

	$0 <check_code|dev_upload>

EOF
}

function_files_get()
{
	local scriptdir

	scriptdir="$( CDPATH='' cd -- "$( dirname -- "$0")" && pwd )"
	printf '%s\n' "$scriptdir/rexxbot-plugins/"*
}

function_files_include()
{
	# shellcheck disable=SC1091
	for _ in $( function_files_get ); do . "$_"; done
}

# === loop1 | fastscan === TODO: versions of files.txt
# 1) scan direcory and get 4 values:
#    a) type of object (e.g. file or dir)
#    b) modification time
#    c) filesize
#    d) /full/path/and/filename in [base64] format
#   >files.txt
#
# === loop2 | index only new/changed objects ===
# 2) read files.txt and query database for each line
#    a) is this quadruple known?
#
# 3) if not known, do deeper analysis:
#    a) file?: get sha256
#    b) file?: get mimetype
#    b) write [type,mtime,size,mimetype,dirname,basename,sha256] to database-table OBJECTS
#
# === loop3 | metadata ===
# 1) lookup database which [size+sha256] have missing metadata
#    b) write [size+sha256, json-metadata] to database-table METADATA
#
# === loop4 | archive ISO-unboxing ===
# 1) provide helper
#
# === loop5 | archive unboxing ===
# 2) lookup database which [size+sha256] are unanalysed
#    a) mark [size+sha256] as '{archive:IS-IN-WORK@timestamp}' in database-table METADATA
#    b) unbox archive and
#    c) read each file/dir like loop1
#    d) write [type,mtime,size,dirname,basename,sha256sum] to database table UNBOXED
#    e) mark [size+sha256] as '{archive:unboxed}' 
#
# === loop6 | web-ui ===
# 1) server connections
#
# === loop7 | web-ui-query-completer? ===
# 1) foo
#
# === loop8 | metadate-API check+update ===
# 1) query metadata-plugins and detect database entries with lower metadata API version
#
#######################################################################################


loop1_fastscan()	# deps: find
{
	local dir="$1"

	prepare_db
	find "$dir" -printf "$( findoutput_to_sqlcommands )\n"
}

loop2_mime_and_sha256()		# deps: test
{
	local file mime sha256

	while true; do {
		file="$( db_select_nextfile_without_mime )"
		[ -f "$file" ] || return 1

		mime="$( mimetype_get "$file" )"
		sha256="$( sha256_get "$file" )"

		# autodeletes 'queued' keyword in sha256
		db_insert_mime_and_sha256 "$file" "$mime" "$sha256"
	} done
}

function_files_include

case "$ACTION" in
	table_drop)
		set -x
		db_query "DROP TABLE objects"
		db_query "DROP TABLE metadata"
	;;
	table_show)
		CONDITION=
		test -n "$ARG1" && CONDITION="WHERE $ARG1 = '$ARG2'"

		db_query "SELECT * FROM objects $CONDITION" human
		db_query "SELECT * FROM metadata" human
	;;
	table_show_files)
		db_query "SELECT * FROM objects WHERE type = 'f'" human
	;;
	table_show_meta)
		db_query "SELECT * FROM metadata" human
	;;
	fastscan)
		loop1_fastscan "${ARG1:-testdir}" | pump_into_db
	;;
	mimesha)
		loop2_mime_and_sha256
	;;
	like)
		# https://www.cybertec-postgresql.com/en/postgresql-more-performance-for-like-and-ilike-statements/
	;;
	refill)
		$0 table_drop
		$0 fastscan "${ARG1:-testdir/}"
		$0 table_show_files | wc -l
		$0 table_show_files | head -n5
		echo
		$0 table_show_meta  | head -n5
		echo

		while true; do {
			$0 atomic || break
		} done

		C1="$( db_query 'select count(distinct(sha256)) from objects  where sha256 is not null' )"
		C2="$( db_query 'select count(distinct(sha256)) from metadata where sha256 is not null' )"
		C3="$( db_query "select count(sha256) from metadata where data->'rc' = '1';" )"
		C4="$( db_query "select count(sha256) from metadata where data is null and mime like 'image/%';" )"
		C5="$( db_query "select count(sha256) from metadata where preview is null and mime like 'image/%';" )"
		# select data->>'colors' from metadata where data->>'colors' is not null;

		echo
		echo "unique files in objects: $C1"
		echo "files in meta: $C2"
		echo "rc=1 faelle: $C3"
		echo "leeres image-data-json: $C4"
		echo "leeres image-preview-json: $C5"
	;;
	atomic)
		# table: objects
		id="$( db_fetch_nextfile_without_sha256 )"	# mark as 'queued'
		log "id: '$id'"
		test -z "$id" && exit 1

		file="$( db_select_file_from_id "$id" )" || exit 1
		log "file: '$file'"

		mime="$( mimetype_get "$file" )"
		sha256="$( sha256_get "$file" )"

		# table: objects + metadata
		# autodeletes 'queued' keyword in sha256
		id="$( db_insert_mime_and_sha256 "$id" "$mime" "$sha256" || log "inserted rc: $?" )"
		[ -z "$id" ] && log "id: '$id'" && exit 0	# metadata already filled

		case "$mime" in
			'image/'*|'audio'/*)
				meta="$(   "metadata_get_${mime%/*}" "$file" )"
				preview="$( "preview_get_${mime%/*}" "$file" )"
				db_insert_meta_and_preview "$sha256" "$meta" "$preview" || \
					log "db_insert_meta_and_preview: rc: $?"
			;;

			*) log "not handled mime: '$mime'" ;;
		esac

		# log "ready-insert"
	;;
	show_images)
		find "$ARG1" -type f | while read -r LINE; do {
			MIME="$( mimetype_get "$LINE" )"
			MIMEPRE="${MIME%/*}"
			MIMESUB="${MIME#*/}"

			case "$MIMEPRE" in
				image) echo "# $LINE" && feh "$LINE" ;;
			esac
		} done
	;;
	mime)
		# mimetype_get "$ARG1"
		MIME="$( mimetype_get "$ARG1" )"
		MIMEPRE="${MIME%/*}"
		MIMESUB="${MIME#*/}"	# unused

		echo "detected: $MIME (pre: $MIMEPRE sub: $MIMESUB) -> $ARG1" >>T

		case "$MIMEPRE" in
			image)
				funcname_meta="metadata_get_${MIMEPRE}"
				funcname_preview="preview_get_${MIMEPRE}"
			;;
			audio)
				funcname_meta="metadata_get_${MIMEPRE}"
				funcname_preview="preview_get_${MIMEPRE}"
			;;
			*)
				exit 0

				# funcname_meta="metadata_get_${MIMEPRE}_${MIMESUB}"
				# funcname_preview="preview_get_${MIMEPRE}_${MIMESUB}"
			;;
		esac

		# deps: jq
		if LC_ALL=C command -v "$funcname_meta" >/dev/null; then
			echo "# file: '$ARG1'"
			$funcname_meta    "$ARG1" >/tmp/T
			cat /tmp/T
			jq . </tmp/T >/dev/null || { echo "jq-error:$? #############" && exit; }
			$funcname_preview "$ARG1"
		else
			echo "missing: $MIME -> $funcname_meta | $file" >>T
		fi
	;;
	depspre)
		dependencies_get
	;;
	deps)
		dependencies_check "$ARG1"
	;;
	check_code)
		check_code
	;;
	dev_upload)
		dev_upload
	;;
	foo)
		json_keyvalue "foo" '' last
	;;
	*)
		usage && false
	;;
esac
