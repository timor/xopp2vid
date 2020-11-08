USING: cairo-gadgets cairo.ffi cairo.surface-gadget locals math math.constants
math.rectangles tools.test ui.gadgets ;
IN: cairo.surface-gadget.tests

TUPLE: arc-gadget < gadget ;
INSTANCE: arc-gadget cairo-render-gadget
M: arc-gadget pref-rect* drop { 0 0 } { 128 128 } <rect> ;
M:: arc-gadget render-cairo* ( gadget -- )
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
