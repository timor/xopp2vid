USING: accessors arrays assocs cairo cairo-gadgets cairo.ffi colors.constants
colors.hex combinators.short-circuit destructors formatting grouping images
images.loader images.memory.private io.backend io.directories kernel locals math
math.functions math.parser math.rectangles math.vectors memoize namespaces
sequences sequences.extras sequences.zipped splitting strings vectors xml.data
xml.traversal ;

IN: xopp

! * Xournal++ file loader

SYMBOL: audio-path

: pages ( xml -- seq )
    "page" tags-named ;

: all-page-strokes ( xml-page -- seq )
    "stroke" deep-tags-named ;

: string>numbers ( str -- seq )
    " " split [ string>number ] map ;

: stroke-points ( stroke -- seq )
    children>string string>numbers 2 <groups> ;

: stroke-segments ( stroke -- seq )
    [ "width" attr string>numbers ] [ stroke-points 2 <clumps> ] bi <zipped> ;

: segment-length ( segment -- n )
    second first2 distance ;

:: (draw-segment) ( width start end -- )
    cr width cairo_set_line_width 
    cr start first2 cairo_move_to
    cr end first2 cairo_line_to
    cr cairo_stroke ;

: draw-segment ( segment -- ) first2 first2 (draw-segment) ; inline

: draw-segments ( color segments -- )
    [ cr swap set-source-color ] [ [ draw-segment ] each ] bi* ;

: stroke>color/seg ( stroke -- color segments )
    [ "color" attr 1 tail hex>rgba ] [ stroke-segments ] bi ;

: draw-stroke ( stroke -- )
    [ color>> ] [ segments>> ] bi draw-segments ;
    ! stroke>color/seg draw-segments ;
    ! [ cr swap "color" attr 1 tail hex>rgba set-source-color ]
    ! [ stroke-segments [ first2 draw-segment ] assoc-each ] bi ;

: draw-layer ( layer -- ) "stroke" tags-named [ draw-stroke ] each ;

: draw-page ( page -- ) "layer" tags-named [ draw-layer ] each ;

: even-integer ( number -- int )
    ceiling >integer dup even? [ 1 + ] unless ;

: page-dim ( page -- dim )
    [ "width" attr string>number even-integer ] [ "height" attr string>number even-integer 2array ] bi ;

: make-page-image ( page quot: ( -- ) -- image )
    [ page-dim ] dip
    [ current-cairo set ] prepose make-bitmap-image ; inline

: page>bitmap-image ( page -- image )
    ! [ "width" attr string>number ceiling >integer ] [ "height" attr string>number ceiling >integer 2array ] [ ] tri
    ! [ swap current-cairo set draw-page ] curry make-bitmap-image ;
    dup [ draw-page ] curry make-page-image ;


TUPLE: clip audio strokes ;
: <clip> ( audio -- obj ) clip new swap >>audio V{ } clone >>strokes ;
TUPLE: stroke color segments ;
: <stroke> ( xml -- obj )
    stroke>color/seg stroke boa ;

SYMBOL: current-clips
SYMBOL: last-clip
SINGLETON: +no-clip+

: with-current-clips ( quot -- )
    [ V{ } clone current-clips ] dip [ +no-clip+ last-clip set ] prepose with-variable ; inline

PREDICATE: longlongattr < string 2 tail-slice* "ll" sequence= ;
GENERIC: attr>number ( str -- number )
M: longlongattr attr>number 2 head-slice* string>number ;

: stroke-clip-info ( stroke -- clip timestamp )
    [ "fn" attr f or ] [ "ts" attr attr>number ] bi ;

: update-current-clip ( audio -- )
    dup last-clip get = [ dup <clip> current-clips get push ] unless
    last-clip set ;

: change-clip ( stroke -- ) stroke-clip-info drop update-current-clip ;

: page-clips ( page -- seq )
    [
        all-page-strokes
        [ [ change-clip ] [ <stroke> current-clips get last strokes>> push ] bi ] each
        current-clips get
    ] with-current-clips ;

SYMBOL: path-suffix
! pts/second
SYMBOL: stroke-speed
stroke-speed [ 180 ] initialize
! fps/second
SYMBOL: fps
fps [ 30 ] initialize

MEMO: (frame-time) ( fps -- seconds ) recip ;
: frame-time ( -- seconds ) fps get (frame-time) ;

: segment-time ( segment -- seconds )
    segment-length stroke-speed get /f ;

SYMBOL: segment-timer

:: with-image-surface ( dim quot -- )
    [
    dim malloc-bitmap-data :> bitmap-data
    bitmap-data dim <image-surface> &cairo_surface_destroy :> surface
    surface <cairo> &cairo_destroy dup check-cairo current-cairo set
    surface quot curry call
    ] with-destructors ; inline

:: write-frame ( path-prefix surface -- )
    surface dup cairo_surface_flush path-prefix path-suffix [ 0 or 1 + dup ] change "%s-%05d.png" sprintf cairo_surface_write_to_png (check-cairo) ;

:: (write-stroke-frames) ( path-prefix stroke surface dim -- )
    cr COLOR: white set-source-color
    cr { 0 0 } dim <rect> fill-rect
    stroke [ color>> ] [ segments>> ] bi :> ( color segments )
    cr color set-source-color
    segments reverse clone >vector :> segments
    [ { [ segments empty? not ] [ segment-timer get 0 < ] } 0|| ]
    [
        segment-timer get 0 >=
        [ segments pop [ draw-segment ] [ segment-time segment-timer [ swap - ] change ] bi ] when
        segment-timer get 0 <=
        [ path-prefix surface write-frame
          segment-timer [ frame-time + ] change
        ] when
    ] while ;

:: write-stroke-frames ( path-prefix dim stroke -- )
    path-prefix normalize-path :> path-prefix
    dim
    [| surface |
        ! 0 segment-timer set
        ! 0 path-suffix set
        path-prefix stroke surface dim (write-stroke-frames)
    ] with-image-surface ;

: move-speed ( -- pt/sec ) stroke-speed get 2 * ;

: inter-stroke-time ( stroke1 stroke2 -- seconds )
    [ segments>> last ] [ segments>> first ] bi* [ second ] bi@
    distance move-speed get /f ;

SYMBOL: last-stroke
:: write-stroke-pause ( path-prefix surface stroke -- )
    last-stroke get
    [
        stroke inter-stroke-time fps /f ceiling round >integer
        [ path-prefix surface write-frame ] times
    ] when* ;

:: write-clip-frames ( path-prefix dim clip -- )
    path-prefix normalize-path :> path-prefix
    dim [| surface |
     0 segment-timer set
     0 path-suffix set
     clip strokes>>
     [| stroke i |
      path-prefix surface stroke write-stroke-pause
      path-prefix i "%s-%d" sprintf :> dir
      dir make-directories
      dir "/frame" append stroke surface dim (write-stroke-frames)
     ] each-index
    ] with-image-surface ;
