! Copyright (C) 2020 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays cairo cairo-gadgets cairo.ffi colors.hex grouping kernel
math math.functions math.parser math.rectangles math.vectors sequences
sequences.zipped splitting stroke-unit.elements stroke-unit.util
ui.gadgets.desks xml.data xml.traversal ;
IN: stroke-unit.strokes

: string>numbers ( str -- seq )
    ! " " split-slice [ string>number ] <map> ;
    " " split-slice [ string>number ] map ;

: stroke-points ( stroke -- seq )
    children>string string>numbers 2 <groups> ;

: stroke-segments ( stroke -- seq )
    [ "width" attr string>numbers ] [ stroke-points 2 <clumps> ] bi <zipped> ; ! memo-scope

: segment-length ( segment -- n )
    second first2 distance ; inline

: stroke>color/seg ( stroke -- color segments )
    [ "color" attr 1 tail hex>rgba ] [ stroke-segments ] bi ;

: stroke-audio ( stroke -- name )
    "fn" attr ; inline

:: draw-segment ( segment -- )
    segment first2 first2 :> ( width start end )
    cr width cairo_set_line_width
    cr start first2 cairo_move_to
    cr end first2 cairo_line_to
    cr cairo_stroke ; inline

PREDICATE: stroke < tag name>> main>> "stroke" = ;

GENERIC: draw-stroke ( stroke -- )

: set-stroke-params ( color -- )
    cr swap set-source-color
    cr CAIRO_OPERATOR_SOURCE cairo_set_operator
    cr CAIRO_LINE_JOIN_ROUND cairo_set_line_join
    cr CAIRO_LINE_CAP_ROUND cairo_set_line_cap
    ;

M: stroke draw-stroke
    stroke>color/seg
    [ set-stroke-params ]
    [ [ draw-segment ] each ] bi* ;

: (stroke-rect) ( stroke -- rect )
    ! stroke-segments [ second ] <map> concat rect-containing ; inline
    stroke-segments [ second ] map concat rect-containing ; inline

: strokes-rect ( strokes -- rect )
    [ <zero-rect> ]
    [ [ (stroke-rect) ] [ rect-union ] map-reduce ] if-empty
    ! TODO: Check for errors because loc can become negative after padding
    1 pad-rect ;

: stroke-rect ( stroke -- rect ) 1array strokes-rect ;

: strokes-dim ( strokes -- dim ) strokes-rect dim>> [ ceiling >integer ] map ;

M: stroke element-rect stroke-rect ;

M: stroke pref-rect* 1array strokes-rect ;
M: stroke pref-loc* pref-rect* loc>> ;
M: stroke render-cairo* draw-stroke ;
