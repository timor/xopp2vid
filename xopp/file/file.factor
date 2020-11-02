USING: accessors compression.zlib.ffi io.encodings.binary io.files ;

IN: xopp.file

: <gz-file-reader> ( path -- gzFile )
    binary <file-reader> handle>> fd>> "r" gzdopen ;
