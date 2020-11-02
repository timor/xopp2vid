USING: cairo-gadgets cairo-gadgets.private cairo.ffi cairo.svg.ffi fry
io.backend kernel ;

IN: cairo.svg

: with-cairo-svg ( path width-pt height-pt quot -- )
    [ normalize-path ] 3dip [ cairo_svg_surface_create ] dip over '[ cr cairo_destroy _ cairo_surface_destroy ] compose with-cairo-from-surface ; inline
