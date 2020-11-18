USING: accessors arrays cairo cairo-gadgets cairo.ffi combinators.short-circuit
images images.memory.private kernel locals make math math.rectangles
math.vectors memoize namespaces sequences stroke-unit.strokes stroke-unit.util
vectors ;

IN: stroke-unit.clip-renderer

! * Render a clip to a sequence of bitmap images

SYMBOL: segment-timer

SYMBOL: stroke-speed
stroke-speed [ 70 ] initialize
SYMBOL: scale-factor
scale-factor [ 1 ] initialize
SYMBOL: travel-speed-factor
travel-speed-factor [ 1 ] initialize

: travel-speed ( -- pt/sec ) stroke-speed get travel-speed-factor get * ;

MEMO: (frame-time) ( fps -- seconds ) recip ;
: frame-time ( -- seconds ) fps get (frame-time) ;

: segment-time ( segment -- seconds )
    segment-length stroke-speed get /f ; inline

: clip-strokes ( clip -- seq )
    elements>> [ stroke? ] filter ;

: clip-rect ( clip -- rect )
    clip-strokes strokes-rect scale-factor get rect-scale ;

: surface-dim ( surface -- dim )
    [ cairo_image_surface_get_width ]
    [ cairo_image_surface_get_height ] bi 2array ; inline

! Assume RGBA Data!
: surface>image ( surface -- image )
    [ cairo_surface_flush ]
    [ cairo_image_surface_get_data ]
    [ surface-dim ] tri <bitmap-image>
    BGRA >>component-order ubyte-components >>component-type ;

SYMBOL: stroke-num
SYMBOL: stroke-nums

: add-frame ( surface -- ) surface>image ,
    ! stroke-num get stroke-nums get push
    ;

:: render-stroke-frames ( stroke surface -- )
    stroke stroke>color/seg :> ( color segments )
    cr color set-source-color
    segments reverse clone >vector :> segments
    surface add-frame
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

: inter-stroke-length ( stroke1 stroke2 -- pts )
    [ stroke-segments last ] [ stroke-segments first ] bi* [ second ] bi@
    [ second ] [ first ] bi* distance ;

: inter-stroke-time ( stroke1 stroke2 -- seconds )
    inter-stroke-length travel-speed /f ;

SYMBOL: last-stroke
:: add-inter-stroke-pause ( stroke -- )
    last-stroke get
    [ stroke inter-stroke-time segment-timer [ swap - ] change ] when* ;

! Return a sequence of images that are the clip's frames
! TODO: memo-cache stroke-segments here
:: render-clip-frames ( clip -- frames )
    clip clip-rect rect-bounds ceiling-dim :> ( loc dim )
    clip clip-strokes :> strokes
    ! V{ } clone stroke-nums set
    ! 0 stroke-num set
    [ dim [| surface |
           0 segment-timer set
           last-stroke off
           cr loc first2 [ neg ] bi@ cairo_translate
           cr scale-factor get dup cairo_scale
           strokes [
               [ add-inter-stroke-pause ]
               [ surface render-stroke-frames ]
               [ last-stroke set ] tri
               ! stroke-num inc
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

! Calculate the index of the strokes which corresponds to the given time after
! clip start
! :: clip-time-stroke-index ( clip offset -- i )
!     0 :> time!
!     clip clip-strokes 2 <clumps>
!     [ first2 :> ( s1 s2 )
!       time offset >=
!       [ s1 ]
!       [

!       ]

!     ] find drop
