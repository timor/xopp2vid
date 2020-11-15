! Copyright (C) 2020 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays cairo cairo-gadgets cairo.ffi cairo.surface-renderer
colors.hex grouping kernel locals math math.functions math.parser
math.rectangles math.vectors memoize.scoped sequences sequences.mapped
sequences.zipped splitting ui.gadgets.desks xml.data xml.traversal ;
IN: stroke-unit.strokes

: string>numbers ( str -- seq )
    " " split-slice [ string>number ] <map> ;

: stroke-points ( stroke -- seq )
    children>string string>numbers 2 <groups> ;

: stroke-segments ( stroke -- seq )
    [ "width" attr string>numbers ] [ stroke-points 2 <clumps> ] bi <zipped> ; memo-scope

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

: draw-stroke ( stroke -- )
    stroke>color/seg
    [ cr swap set-source-color ]
    [ [ draw-segment ] each ] bi* ;

: stroke-rect ( stroke -- rect )
    stroke-segments [ second ] <map> concat rect-containing ; inline

: strokes-rect ( strokes -- rect )
    [ stroke-rect ] [ rect-union ] map-reduce ;

: strokes-dim ( strokes -- dim ) strokes-rect dim>> [ ceiling >integer ] map ;

! : stroke-element? ( xml -- ? ) "stroke" assure-name swap tag-named? ; inline

PREDICATE: stroke < tag name>> main>> "stroke" = ;

! Presenting a single stroke at it's actual position, parent object responsible for supplying enough drawing space
! TUPLE: stroke-gadget < stroke ;
! ! TUPLE: stroke-gadget < gadget stroke ;
! ! INSTANCE: stroke-gadget cairo-render-gadget
! : <stroke-gadget> ( stroke -- obj ) 1array <cairo-renderer> stroke-gadget new swap >>stroke ;

M: stroke pref-rect* 1array strokes-rect ;
M: stroke pref-loc* pref-rect* loc>> ;
M: stroke render-cairo* draw-stroke ;

! M: stroke-gadget render-cairo*
!     stroke>> draw-stroke ;
    ! [ stroke>> [
    !     stroke-rect loc>>
    !     cr swap first2 [ neg ] bi@ cairo_translate
    ! ] [ draw-stroke ] bi ] with-saved-cairo-matrix ;
