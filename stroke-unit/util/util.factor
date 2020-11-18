USING: accessors alien audio audio.engine audio.vorbis byte-arrays byte-vectors
cairo cairo-gadgets cairo.ffi calendar classes.struct combinators destructors
fry images.memory.private io.backend kernel locals math math.functions
namespaces sequences strings xml xml.data xml.traversal ;

IN: stroke-unit.util

: ceiling-dim ( dim -- dim )
    [ ceiling >integer ] map ; inline

: rect-scale ( rect factor -- rect' )
    [ clone ] dip
    '[ _ v*n ] [ change-dim ] [ change-loc ] bi ;

SYMBOL: current-audio-folder

! frames/second
SYMBOL: fps
fps [ 25 ] initialize

: get-current-audio-folder ( -- path )
    current-audio-folder
    [ [ "~/.xournalpp/settings.xml" normalize-path file>xml
        "property" tags-named [ "name" attr "audioFolder" = ] find nip
        [ "value" attr "file://" drop-prefix drop >string ] [ f ] if*
      ] unless* ] change
    current-audio-folder get ;

: with-factor-image-surface ( image quot: ( surface -- ) -- )
    '[
        _ [ bitmap>> ] [ dim>> ] bi <image-surface> &cairo_surface_destroy
        @
    ] with-destructors ; inline

:: with-image-surface ( dim quot -- )
    [
        dim malloc-bitmap-data :> bitmap-data
        bitmap-data dim <image-surface> &cairo_surface_destroy :> surface
        surface <cairo> &cairo_destroy dup check-cairo current-cairo set
        surface quot curry call
    ] with-destructors ; inline

! TUPLE: cairo-image-gadget < image-gadget ;

! M:: cairo-image-gadget draw-gadget* ( gadget -- )
!     gadget dup dim>> [
!         current-cairo set
!         gadget render-cairo*
!     ] make-bitmap-image >>image
!     call-next-method ;

:: with-saved-cairo-matrix ( quot -- )
    cairo_matrix_t <struct> :> matrix
    cr matrix cairo_get_matrix
    quot call
    cr matrix cairo_set_matrix ; inline

CONSTANT: center-source T{ audio-source f {  0.0 0.0 0.0 } 1.0 { 0.0 0.0 0.0 } f }

:: play-vorbis-file ( filename -- audio-clip )
    f 4 <audio-engine> :> engine
    engine start-audio
    engine
    center-source
    filename 16384 read-vorbis-stream
    2
    play-streaming-audio-clip ;

! Inefficiently decode ogg and create big chunk of memory
:: ogg>pcm ( stream -- byte-array )
    0 <byte-vector> :> vec
    [
        stream generate-audio :> ( buffer length )
        length 0 > [ vec buffer length head-slice append! drop t ]
        [ f ] if
    ] loop vec >byte-array ;

: ogg>audio ( filename -- audio )
    32768 read-vorbis-stream
    [ generator-audio-format 0 f <audio> ]
    [ ogg>pcm [ length >>size ] [ >>data ] bi ] bi ;

: audio-duration ( audio -- duration )
    { [ size>> ]
      [ channels>> ]
      [ sample-bits>> 8 / * ]
      [ sample-rate>> * ]
     } cleave / seconds ;

: audio-slice ( audio offset -- audio' )
    [ clone ] dip
    [ [ - ] curry change-size ]
    [ [ swap <displaced-alien> ] curry change-data ] bi ;

: audio-bytes ( audio -- seq ) [ data>> ] [ size>> ] bi memory>byte-array ;
: audio-sample-size ( audio -- bytes ) sample-bits>> 8 / ;
: audio-packet-size ( audio -- bytes ) [ audio-sample-size ] [ channels>> ] bi * ;
: audio-normalize-scale ( audio -- x ) sample-bits>> 1 - 2^ ;

: audio-values ( audio -- seq )
    { [ data>> ]
      [ audio-packet-size <groups> ]
      [ audio-sample-size [ <groups> ] curry map <flipped> ]
      [ [ sample-bits>> ] [ audio-normalize-scale ] bi '[ [ _ signed-endian> _ /f ] <map> ] map ] } cleave ;

: color>bytes ( color -- seq )
    >rgba-components [ spin ] dip 4array [ 255 * >integer ] B{ } map-as ;

:: audio-image-column ( value height fg bg -- seq )
    height <iota> [ value height * < fg bg ? color>bytes ] map <reversed> ;

:: bg-column ( height bg -- seq )
    height [ bg color>bytes ] replicate ;

:: audio-image ( audio channel width height fg bg -- image )
    channel audio audio-values nth [ abs ] <map> :> values
    values length width /i :> chunks
    values chunks <groups> [ supremum ] map
    :> levels
    width <iota> [| x | x levels ?nth
                  [ height fg bg audio-image-column ]
                  [ height bg bg-column ] if* ] map <flipped> concat
    concat
    <image> swap >>bitmap width height 2array >>dim
    ubyte-components >>component-type
    BGRA >>component-order ;


: alpha-color ( color alpha -- rgba )
    [ >rgba-components drop ] dip <rgba> ;
