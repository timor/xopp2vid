USING: accessors kernel stroke-unit.elements xml.traversal xopp.file ;

USE: stroke-unit.util
USE: stroke-unit.clips
USE: stroke-unit.page
IN: stroke-unit

TUPLE: project path pages ;
TUPLE: page layers ;
TUPLE: layer clips ;

: load-xopp-file ( path -- xml )
    file>xopp ;
