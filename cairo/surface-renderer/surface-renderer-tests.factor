USING: accessors alien.c-types arrays cairo-gadgets cairo.ffi
cairo.surface-renderer kernel locals math math.constants math.rectangles models
models.arrow sequences specialized-arrays ;
IN: cairo.surface-renderer.tests

TUPLE: cairo-sample ;
M: cairo-sample pref-rect* drop { 0 0 } { 256 256 } <rect> ;
TUPLE: sample-arc < cairo-sample ;
! INSTANCE: sample-arc cairo-render-gadget
M:: sample-arc render-cairo* ( gadget -- )
    128.0 :> xc
    128.0 :> yc
    100.0 :> radius
    pi 1/4 * :> angle1
    pi :> angle2
    cr 10.0 cairo_set_line_width
    cr xc yc radius angle1 angle2 cairo_arc
    cr cairo_stroke

    ! draw helping lines
    cr 1 0.2 0.2 0.6 cairo_set_source_rgba
    cr 6.0 cairo_set_line_width

    cr xc yc 10.0 0 2 pi * cairo_arc
    cr cairo_fill

    cr xc yc radius angle1 angle1 cairo_arc
    cr xc yc cairo_line_to
    cr xc yc radius angle2 angle2 cairo_arc
    cr xc yc cairo_line_to
    cr cairo_stroke
    ;

SPECIALIZED-ARRAY: double

TUPLE: sample-dash < cairo-sample ;
M:: sample-dash render-cairo* ( gadget -- )
    double-array{ 50 10 10 10 } underlying>> :> dashes
    4 :> ndash
    cr dashes ndash -50 cairo_set_dash
    cr 10 cairo_set_line_width
    cr 128.0 25.6 cairo_move_to
    cr 230.4 230.4 cairo_line_to
    cr -102.4 0 cairo_rel_line_to
    cr 51.2 230.4 51.2 128.0 128.0 128.0 cairo_curve_to
    cr cairo_stroke ;

: test-renderer ( -- model gadget )
    sample-arc new 1array <cairo-renderer> ;

:: selector-model ( -- model model )
    sample-dash new 1array render-cairo-sequence
    sample-arc new 1array render-cairo-sequence
    2array :> images
    t <model> dup [ [ images first ] [ images second ] if ] <arrow> ;
