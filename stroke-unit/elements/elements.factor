! Copyright (C) 2020 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: math.rectangles sequences stroke-unit.util xml.traversal ;
IN: stroke-unit.elements

: strokes ( xml -- seq ) "stroke" tags-named ;

: layers ( xml -- seq ) "layer" tags-named ;

: pages ( xml -- seq ) "page" tags-named ;

: elements ( xml -- seq ) children-tags ;

GENERIC: element-rect ( xml -- rect )

: elements-rect ( seq -- rect )
    [ <zero-rect> ]
    [ [ element-rect ] [ rect-union ] map-reduce ] if-empty
    ! TODO: Check for errors because loc can become negative after padding
    1 pad-rect ;
