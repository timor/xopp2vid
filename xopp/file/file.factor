USING: accessors alien.c-types alien.syntax combinators
combinators.short-circuit compression.zlib.ffi destructors io io.backend kernel
libc math namespaces sequences sequences.extras strings tools.continuations xml
;

IN: xopp.file

! * Gzip file reader

LIBRARY: zlib

FUNCTION: gzFile gzopen ( c-string path, c-string mode )

ERROR: gzip-error gzfile message ;

: check-gzfile ( result gzfile -- result  )
    { { [ over 0 >= ] [ drop ] }
      { [ over Z_ERRNO = ] [ break 2drop throw-errno ] }
      [ break over gzerror gzip-error ]
    } cond ; inline

TUPLE: gz-file-reader < disposable gzfile last-chars ;
INSTANCE: gz-file-reader input-stream

: record-last-char ( reader char -- char )
    swap dupd last-chars>> [ set-first ] [ 1 rotate! ] bi ;

: <gz-file-reader> ( path -- obj )
    "r" gzopen dup
    [ gz-file-reader new-disposable swap >>gzfile 10 0 <string> >>last-chars ]
    [ throw-errno ] if ;

M: gz-file-reader stream-element-type drop +byte+ ; inline

M: gz-file-reader dispose* gzfile>>
    [ gzclose ] [ check-gzfile ] bi drop ;

: catch-eof ( result gzfile -- result )
    { [ drop -1 = ] [ nip gzeof 1 = ] } 2&& f t ? ;

M: gz-file-reader stream-read1 gzfile>>
    [ gzgetc ] [ { [ catch-eof ] [ check-gzfile ] } 2&& ] bi ;

M: gz-file-reader stream-read-unsafe gzfile>>
    [ spin gzread ] [ check-gzfile ] bi ;

: file>xopp ( path -- xml )
    normalize-path <gz-file-reader> [ input-stream get read-xml ] with-input-stream ;
