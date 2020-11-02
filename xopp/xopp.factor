USING: accessors arrays assocs cairo cairo-gadgets cairo.ffi colors.constants
colors.hex destructors formatting grouping images images.loader
images.memory.private kernel locals math math.functions math.parser
math.rectangles namespaces sequences sequences.extras sequences.zipped splitting
strings xml.data xml.traversal ;

IN: xopp

! * Xournal++ file loader

SYMBOL: audio-path

: pages ( xml -- seq )
    "page" tags-named ;

: all-page-strokes ( xml-page -- seq )
    "stroke" deep-tags-named ;

: string>numbers ( str -- seq )
    " " split [ string>number ] map ;

: stroke-segments ( stroke -- seq )
    [ "width" attr string>numbers ] [ children>string string>numbers 2 <groups> 2 <clumps> ] bi <zipped> ;

:: draw-segment ( width start end -- )
    cr width cairo_set_line_width 
    cr start first2 cairo_move_to
    cr end first2 cairo_line_to
    cr cairo_stroke ;

: draw-segments ( color segments -- )
    [ cr swap set-source-color ] [ [ first2 draw-segment ] assoc-each ] bi* ;

: stroke>color/seg ( stroke -- color segments )
    [ "color" attr 1 tail hex>rgba ] [ stroke-segments ] bi ;

: draw-stroke ( stroke -- )
    stroke>color/seg draw-segments ;
    ! [ cr swap "color" attr 1 tail hex>rgba set-source-color ]
    ! [ stroke-segments [ first2 draw-segment ] assoc-each ] bi ;

: draw-layer ( layer -- ) "stroke" tags-named [ draw-stroke ] each ;

: draw-page ( page -- ) "layer" tags-named [ draw-layer ] each ;

: page-dim ( page -- dim )
    [ "width" attr string>number ceiling >integer ] [ "height" attr string>number ceiling >integer 2array ] bi ;

: make-page-image ( page quot: ( -- ) -- image )
    [ page-dim ] dip
    [ current-cairo set ] prepose make-bitmap-image ; inline

: page>bitmap-image ( page -- image )
    ! [ "width" attr string>number ceiling >integer ] [ "height" attr string>number ceiling >integer 2array ] [ ] tri
    ! [ swap current-cairo set draw-page ] curry make-bitmap-image ;
    dup [ draw-page ] curry make-page-image ;


TUPLE: clip audio strokes ;
: <clip> ( audio -- obj ) clip new swap >>audio V{ } clone >>strokes ;
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
        [ [ change-clip ] [ current-clips get last strokes>> push ] bi ] each
        current-clips get
    ] with-current-clips ;

SYMBOL: path-suffix
:: write-stroke-frames ( path-prefix page stroke -- )
    [
        0 path-suffix set
        page page-dim :> dim
        dim malloc-bitmap-data :> bitmap-data
        bitmap-data dim <image-surface> &cairo_surface_destroy :> surface
        surface <cairo> &cairo_destroy dup check-cairo current-cairo set
        cr COLOR: white set-source-color
        cr { 0 0 } dim <rect> fill-rect
        stroke stroke>color/seg :> ( color segments )
        cr color set-source-color
        segments [
            first2 draw-segment
            surface [ cairo_surface_flush ] [ check-surface ] bi
            bitmap-data dim <bitmap-image> BGRA >>component-order ubyte-components >>component-type :> image
            image path-prefix path-suffix [ 0 or 1 + dup ] change "%s-%05d.png" sprintf save-graphic-image
        ] assoc-each
    ] with-destructors ;

: stroke-frames ( page stroke -- seq )
    stroke>color/seg [ [ draw-segments ] 2curry make-page-image ] 2with collector [ each-subseq ] dip ;

: clip-frames ( page clip -- seq )
    strokes>> [ stroke-frames ] with map ;
