### What is it?
A desktop search engine for your private files,  
everything works offline, it never uses online-services.

### How does it work?
Scan a directory, extract and enrich metadata, store it  
in database, make it searchable. Also looks inside archives.

### Looking into archives or bundles
It uncompresses archives, or archives in archives.  
For example an ISO-file contains a ZIP, which contains a  
TAR with a Libreoffice-document which contains a MP4, which  
contains audio, video and a picture, which has text in it...

### Metadata extraction and creation
It tries to extract and enrich metadata, e.g.  
* audio: extract cover-pictures and generate text-transcription
* video: extract subtitles
* images: extract faces, text, location, camera etc.

### Inner workings overview
* Job-1: use `find` on a directory to extract and write to database:
 * type of object (e.g. file or dir)
 * modification time
 * filesize
 * /full/path/and/filename
* Job-2: extract checksum and mimetype of all files and write to database:
 * using `sha256sum` and [file](http://astron.com/pub/file/)
* Job-3: extract metadata:
 * for images using [magick](https://imagemagick.org/)
 * for videos using [ffmpeg](https://ffmpeg.org/)
 * for audio using [SoX](https://sox.sourceforge.net/)
 * for text using [libreoffice](https://de.libreoffice.org/)
* Job-4: extract archives or bundles:
 * e.g. unzip, untar, unrar, loop-mount, ...

### Naming 
* rexxbot (initially, around 1993) => bot in the name is not nice
* filebot (already taken: https://www.filebot.net)
* file_cabinet => too arbitrary
* ekuku-bot => bot in the name is not nice
* ekuku-search => ekuku is in wikipedia since ~ may 2012
  ^^^^^^^^^^^^ lets use this

### ToDo:
# === loop1 | fastscan ===
# 1) scan directory and get 4 values:
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
