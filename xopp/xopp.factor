USING: accessors arrays assocs cairo cairo-gadgets cairo.ffi cairo.svg
classes.algebra classes.tuple colors.hex destructors formatting grouping
hashtables images images.loader images.memory.private kernel locals math
math.functions math.parser mirrors namespaces sequences sequences.extras
sequences.zipped splitting strings tools.continuations vocabs.parser xml.data
xml.syntax xml.traversal ;

IN: xopp

! * Xournal++ file loader

SYMBOL: audio-path
TUPLE: xml-tuple children ;
TUPLE: background < xml-tuple type color style ;
TUPLE: stroke < xml-tuple tool fs fn color width ;

TUPLE: page < xml-tuple width height ;
TUPLE: layer < xml-tuple ;
TUPLE: image < xml-tuple left tope right bottom ;
TUPLE: xournal < xml-tuple creator fileversion ;
TUPLE: title < xml-tuple ;
TUPLE: preview < xml-tuple ;

ERROR: no-xml-tuple-class-for name ;

: attr>slot ( mirror xml slot -- )
    [ attr ]
    [ rot set-at ] bi ;

: attrs>slot ( xml tuple slots -- )
    [ <mirror> swap ] dip [ attr>slot ] 2with each ;

DEFER: xml>tuple
: set-children ( xml tuple -- tuple )
    swap children>> [ xml>tuple ] map >>children ;

GENERIC: xml>tuple ( xml -- obj )

M: string xml>tuple ;
M: xml xml>tuple body>> [ xml>tuple ] { } map-as ;
M: tag xml>tuple
    dup name>> main>> search dup xml-tuple class<= not [ drop dup name>> main>> no-xml-tuple-class-for ] when
    [ new ]
    [ all-slots [ name>> ] map "children" swap remove ] bi ! xml tuple slots
    [ attrs>slot ] 2keepd
    set-children ;

: pages ( xml -- seq )
    "page" tags-named ;

: all-page-strokes ( xml-page -- seq )
    "stroke" deep-tags-named ;
CONSTANT: path-attrs H{
    { "fill" "none" }
    { "stroke-linecap" "round" }
    { "stroke-linejoin" "round" }
    { "stroke-opacity" "1" }
    { "clip-to-self" "true" }
    { "stroke-miterlimit" "10" }
}

: assoc>style ( assoc -- str ) [ "%s:%s;" sprintf ] { } assoc>map concat ;

: stroke-svg-color ( stroke -- str )
    "color" attr 1 tail hex>rgba [ red>> ] [ green>> ] [ blue>> ] tri 3array
    [ 100 * round "%d%%" sprintf ] map "," join "(" ")" surround "rgb" prepend ;

: segment-svg-style ( color width -- str )
    [ "stroke" associate ] [ "%f" sprintf "stroke-width" associate ] bi*
    path-attrs [ assoc>style ] tri@ append append ;

: string>numbers ( str -- seq )
    " " split [ string>number ] map ;

: stroke-segments ( stroke -- seq )
    [ "width" attr string>numbers ] [ children>string string>numbers 2 <groups> 2 <clumps> ] bi <zipped> ;

: segment>path ( color segment -- xml )
    first2 [ segment-svg-style "style" swap 2array 1array ] dip
    first2 [ first2 ] bi@ "M %f %f L %f %f" sprintf "d" swap 2array suffix
    "path" swap f <tag> ;


: stroke>svg ( stroke -- seq )
    [ stroke-svg-color ] [ stroke-segments ] bi
    [ segment>path ] with map ;

: page>svg-attrs ( page -- width height viewbox )
    [ "width" attr ]
    [ "height" attr ] bi
    [ [ "pt" append ] bi@ ]
    [ "0 0 %s %s" sprintf ] 2bi ;

:: <svg> ( width height viewbox -- xml )
    <XML <svg
    xmlns="http://www.w3.org/2000/svg"
    width=<-width->
    height=<-height->
    viewBox=<-viewbox->
    ></svg> XML> ;

: page>svg ( page -- xml )
    [ page>svg-attrs <svg> ]
    [ all-page-strokes [ stroke>svg ] map ] bi >>children ;


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

: page>svg-file ( page path -- )
    swap [ "width" attr string>number ] [ "height" attr string>number ] [ ] tri
    [ draw-page ] curry with-cairo-svg ;

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
