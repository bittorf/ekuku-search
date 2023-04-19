### What is it?
A desktop search engine for your private files,  
everything works offline, it never uses the internet.

### How does it work?
Scan given directory, extract and enrich metadata, store it  
in a database and make it searchable. Also looks inside archives  
and supports arbitrary file- and foldernames.

### Looking into compressed files, archives or bundles
It uncompresses archives, or archives in archives.  
For example an 7-zip compressed ISO-file contains a ZIP, which  
contains a TAR with a Libreoffice-document which contains a MP4,  
which contains audio, video and a picture, which has text in it...

### Metadata extraction and creation
It tries to extract and enrich metadata, e.g.  
* audio: extract cover-pictures and generate text-transcription
* video: extract subtitles
* images: extract faces, text, location, camera etc.
* and a lot more

### Inner workings overview
#### Job-1 _"fast scan"_
* using `find` on a directory to extract and insert into (or update) database:
  * objecttype (e.g. file or dir)
  * modification time
  * filesize
  * /full/path/and/filename
#### Job-2: _"checksum and MIME"_
* extract checksum and mimetype of all files in database if not known yet or modification time changed
  * `sha256sum`, e.g. from [coreutils](https://git.savannah.gnu.org/gitweb/?p=coreutils.git)
  * filetype using [file](http://astron.com/pub/file/)
#### Job-3: _"metadata: extract and enrich"_
* for images using [magick](https://imagemagick.org/) and [tesseract](https://github.com/tesseract-ocr/tesseract)
* for videos using [ffmpeg](https://ffmpeg.org/)
* for audio using e.g. [SoX](https://sox.sourceforge.net/)
* for text using [libreoffice](https://de.libreoffice.org/)
* for binaries using [binwalk](https://github.com/ReFirmLabs/binwalk)
* insert into (or update) database
#### Job-4: _"uncompress files, extract archives or bundles"_
* e.g. temporarily uncompress, unarchive, and/or loop-mount any filesystem
  * compressor support for `gzip`, `xz`, `zstd`, `bzip2` and others
  * archive support for `zip`, `tar`, `7z`, `rar`, `lha` and others
  * filesystem support for `iso`,`squashfs`, `ext2/3/4`, `qcow2` and others
    * run Job-1/2/3
    * remove extraction or mount

### Why the name _ekuku-search_?
* rexxbot (initially, around 1993) => bot in the name is not nice
* filebot (already taken: https://www.filebot.net)
* file_cabinet => too arbitrary
* ekuku-bot => bot in the name is not nice
* ekuku-search => ekuku is in wikipedia since ~may 2012
* ^^^^^^^^^^^^ lets use this

```
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
```
