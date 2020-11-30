USING: accessors arrays cairo cairo-gadgets cairo.ffi colors.constants
combinators.short-circuit formatting images images.memory.private io.pathnames
kernel locals make math math.rectangles math.vectors memoize namespaces
sequences stroke-unit.elements.images stroke-unit.strokes stroke-unit.util
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

: clip-strokes ( clip -- seq ) elements>> [ stroke? ] filter ;

: clip-images ( clip -- image-elts ) elements>> [ image-elt? ] filter ;

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

SYMBOL: frame-output-path
SYMBOL: path-suffix

:: write-frame ( path-prefix surface -- )
    surface dup cairo_surface_flush path-suffix [ 0 or 1 + dup ] change "-%05d.png" sprintf path-prefix prepend cairo_surface_write_to_png (check-cairo) ;

: (add-frame) ( surface -- ) surface>image ,
    ! stroke-num get stroke-nums get push
    ;

: add-frame ( surface -- )
    frame-output-path get
    [ "frame" append-path swap write-frame ]
    [ (add-frame) ] if* ;

:: render-stroke-frames ( stroke surface -- )
    stroke stroke>color/seg :> ( color segments )
    color set-stroke-params
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
    clip clip-images :> images
    ! V{ } clone stroke-nums set
    ! 0 stroke-num set
    [ dim [| surface |
           0 segment-timer set
           last-stroke off
           cr loc first2 [ neg ] bi@ cairo_translate
           cr scale-factor get dup cairo_scale
           images [ render-cairo* surface add-frame ] each
           strokes [
               [ add-inter-stroke-pause ]
               [ surface render-stroke-frames ]
               [ last-stroke set ] tri
               ! stroke-num inc
          ] each
           ! Intended to fix missing frame at end of preview, TODO: check that does not mess up timing
           surface add-frame
      ] with-image-surface
    ] { } make ;

:: draw-white-bg ( dim -- )
    cr COLOR: white set-source-color
    cr { 0 0 } dim <rect> fill-rect ;

! :: render-page-clip-frames ( dim scale clips -- frames )
!     ! clip clip-rect rect-bounds ceiling-dim :> ( loc dim )
!     ! V{ } clone stroke-nums set
!     ! 0 stroke-num set
!     out-path frame-output-path get
!     [ dim [| surface |
!            ! cr loc first2 [ neg ] bi@ cairo_translate
!            ! cr scale-factor get dup cairo_scale
!            cr scale dup cairo_scale
!            dim draw-white-bg
!            clips [| clip i |
!                   out-path [ i "clip-%02d" sprintf append-path frame-output-path set ] when*
!                   frame-output-path get [ make-directories ] when*
!                   0 path-suffix set
!                   0 segment-timer set
!                   last-stroke off
!                   clip clip-strokes :> strokes
!                   clip clip-images :> images
!                   images [ render-cairo* surface add-frame ] each
!                   strokes [
!                       [ add-inter-stroke-pause ]
!                       [ surface render-stroke-frames ]
!                       [ last-stroke set ] tri
!                       ! stroke-num inc
!                   ] each
!                  ] each-index
!           ] with-image-surface
!     ] { } make ;

: cairo-move-loc ( loc -- )
    cr swap first2 [ neg ] bi@ cairo_translate ;

! TODO: change to element-image? This is actually very close to cairo-gadget...
:: stroke-image ( stroke -- image )
    stroke stroke-rect rect-bounds ceiling-dim
    [
        [ cairo-move-loc ] dip
        stroke draw-stroke
        surface>image
    ] with-image-surface ;

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
