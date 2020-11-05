! Copyright (C) 2020 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors cairo-gadgets cairo.ffi grouping kernel locals math math.parser
math.rectangles memoize.scoped sequences sequences.mapped sequences.zipped
splitting ui.gadgets xml.data xml.traversal ;
IN: stroke-unit.strokes

: string>numbers ( str -- seq )
    " " split-slice [ string>number ] <map> ;

: stroke-points ( stroke -- seq )
    children>string string>numbers 2 <groups> ;

: stroke-segments ( stroke -- seq )
    [ "width" attr string>numbers ] [ stroke-points 2 <clumps> ] bi <zipped> ; memo-scope

:: draw-segment ( segment -- )
    segment first2 first2 :> ( width start end )
    cr width cairo_set_line_width
    cr start first2 cairo_move_to
    cr end first2 cairo_line_to
    cr cairo_stroke ; inline

: draw-stroke ( stroke -- ) stroke-segments [ draw-segment ] each ;

: stroke-rect ( stroke -- rect )
    stroke-segments [ second ] <map> concat rect-containing ;

TUPLE: stroke-gadget < cairo-gadget stroke ;
: <stroke-gadget> ( stroke -- obj ) stroke-gadget new swap >>stroke ;

M: stroke-gadget pref-dim* stroke>> stroke-rect dim>> [ ceiling >integer ] map ;

M: stroke-gadget render-cairo*
    stroke>> [
        stroke-rect loc>>
        cr swap first2 [ neg ] bi@ cairo_translate
        ! drop
    ] [ draw-stroke ] bi ;
