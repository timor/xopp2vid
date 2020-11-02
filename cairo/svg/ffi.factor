USING: alien.c-types alien.syntax ;

IN: cairo.svg.ffi

USE: cairo.ffi

LIBRARY: cairo

FUNCTION: cairo_surface_t
cairo_svg_surface_create ( c-string filename, double width_in_points, double height_in_points )
