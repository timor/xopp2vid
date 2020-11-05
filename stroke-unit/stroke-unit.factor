USING: accessors kernel xml.traversal xopp.file ;

IN: stroke-unit

TUPLE: project path pages ;
TUPLE: page layers ;
TUPLE: layer clips ;
TUPLE: clip audio elements ;


! TBR ( elements )
: strokes ( xml -- seq ) "stroke" tags-named ;

: layers ( xml -- seq ) "layer" tags-named ;

: pages ( xml -- seq ) "page" tags-named ;

: load-xopp-file ( path -- project )
    file>xopp
    project new swap pages >>pages ;
