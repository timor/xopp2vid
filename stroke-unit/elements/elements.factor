! Copyright (C) 2020 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: stroke-unit xml.traversal xopp.file ;
IN: stroke-unit.elements

! TBR ( elements )
: strokes ( xml -- seq ) "stroke" tags-named ;

: layers ( xml -- seq ) "layer" tags-named ;

: pages ( xml -- seq ) "page" tags-named ;
