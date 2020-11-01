USING: accessors arrays assocs classes.algebra classes.tuple colors.hex
formatting grouping hashtables kernel make math math.functions math.parser
mirrors prettyprint sequences sequences.zipped splitting strings vocabs.parser
xml.data xml.traversal ;

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
    [ "width" attr string>numbers ] [ children>string string>numbers 2 group 2 clump ] bi <zipped> ;

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
