USING: accessors kernel models sequences stroke-unit.elements xopp.file ;

USE: stroke-unit.util
USE: stroke-unit.clips
USE: stroke-unit.page
IN: stroke-unit

TUPLE: project path pages ;
TUPLE: page layers ;
TUPLE: layer clips ;

: load-xopp-file ( path -- xml )
    file>xopp ;

: xopp-test ( --  clips editor )
    "~/xournalpp/uebungen/2.1.xopp" load-xopp-file
    pages first page-clips <page-editor> [ clip-displays>> compute-model ] keep ;
