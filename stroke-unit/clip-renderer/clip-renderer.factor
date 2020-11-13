USING: accessors arrays cairo cairo-gadgets cairo.ffi combinators.short-circuit
images images.memory.private kernel locals make math math.rectangles
math.vectors memoize namespaces sequences stroke-unit.strokes stroke-unit.util
vectors ;

IN: stroke-unit.clip-renderer

! * Render a clip to a sequence of bitmap images

SYMBOL: segment-timer

SYMBOL: stroke-speed
stroke-speed [ 70 ] initialize

: travel-speed ( -- pt/sec ) stroke-speed get 1 * ;

MEMO: (frame-time) ( fps -- seconds ) recip ;
: frame-time ( -- seconds ) fps get (frame-time) ;

: segment-length ( segment -- n )
    second first2 distance ; inline

: segment-time ( segment -- seconds )
    segment-length stroke-speed get /f ; inline

: clip-strokes ( clip -- seq )
    elements>> [ stroke? ] filter ;

: clip-rect ( clip -- rect )
    clip-strokes strokes-rect ;

: surface-dim ( surface -- dim )
    [ cairo_image_surface_get_width ]
    [ cairo_image_surface_get_height ] bi 2array ; inline

! Assume RGBA Data!
: surface>image ( surface -- image )
    [ cairo_surface_flush ]
    [ cairo_image_surface_get_data ]
    [ surface-dim ] tri <bitmap-image>
    BGRA >>component-order ubyte-components >>component-type ;

: add-frame ( surface -- ) surface>image , ;

:: render-stroke-frames ( stroke surface -- )
    stroke stroke>color/seg :> ( color segments )
    cr color set-source-color
    segments reverse clone >vector :> segments
    [ { [ segments empty? not ] [ segment-timer get 0 < ] } 0|| ]
    [
        segment-timer get 0 >=
        [ segments pop [ draw-segment ] [ segment-time segment-timer [ swap - ] change ] bi
        ] when
        segment-timer get 0 <=
        [ surface add-frame
          segment-timer [ frame-time + ] change
        ] when
    ] while ;

: inter-stroke-time ( stroke1 stroke2 -- seconds )
    [ stroke-segments last ] [ stroke-segments first ] bi* [ second ] bi@
    [ second ] [ first ] bi*
    distance travel-speed /f ;

SYMBOL: last-stroke
:: add-inter-stroke-pause ( stroke -- )
    last-stroke get
    [ stroke inter-stroke-time segment-timer [ swap - ] change ] when* ;

! Return a sequence of images that are the clip's frames
! TODO: memo-cache stroke-segments here
:: render-clip-frames ( clip -- seq )
    clip clip-rect rect-bounds ceiling-dim :> ( loc dim )
    clip clip-strokes :> strokes
    [ dim [| surface |
           0 segment-timer set
           last-stroke off
           cr loc first2 [ neg ] bi@ cairo_translate
           strokes [
               [ add-inter-stroke-pause ]
               [ surface render-stroke-frames ]
               [ last-stroke set ] tri
          ] each
      ] with-image-surface
    ] { } make ;

: cairo-move-loc ( loc -- )
    cr swap first2 [ neg ] bi@ cairo_translate ;

: clip-image ( clip -- image )
    dup clip-rect rect-bounds ceiling-dim
    [
        [ cairo-move-loc ] dip
        [ clip-strokes [ draw-stroke ] each ] dip
        surface>image
    ] with-image-surface ;
