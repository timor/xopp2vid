USING: accessors alien alien.data arrays audio audio.engine audio.loader
audio.vorbis byte-arrays byte-vectors cairo cairo-gadgets cairo.ffi calendar
calendar.format classes.struct colors columns combinators
combinators.short-circuit continuations destructors endian grouping images
images.memory.private io.backend io.directories io.files io.files.info
io.streams.string kernel math math.functions math.order math.rectangles
math.vectors namespaces sequences sequences.mapped strings threads xml xml.data
xml.traversal ;

IN: stroke-unit.util

! Original save-file-compatibility
: maybe-convert-time ( duration -- seconds )
    dup duration? [ duration>seconds ] when ;

: ceiling-dim ( dim -- dim )
    [ ceiling >integer ] map ; inline

: rect-scale ( rect factor -- rect' )
    [ clone ] dip
    '[ _ v*n ] [ change-dim ] [ change-loc ] bi ;

:: pad-rect ( rect n -- rect' )
    rect rect-bounds
    [ n v-n ]
    [ n 2 * v+n ] bi* <rect> ;

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

! calls quot with surface, cr is set during drawing
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
        yield
    ] loop vec >byte-array ;

: ogg>audio ( filename -- audio )
    32768 read-vorbis-stream
    [ generator-audio-format 0 f <audio> ]
    [ ogg>pcm [ length >>size ] [ >>data ] bi ] bi ;

"ogg" [ ogg>audio ] register-audio-extension

: audio-duration ( audio -- duration )
    { [ size>> ]
      [ channels>> ]
      [ sample-bits>> 8 / * ]
      [ sample-rate>> * ]
     } cleave / ;

: audio-sample-bytes ( audio -- n )
    [ channels>> ]
    [ sample-bits>> 8 / * ] bi ;

: audio-align-offset ( audio offset -- audio offset )
    over audio-sample-bytes 1 - bitnot bitand ;

: audio-slice ( audio offset -- audio' )
    audio-align-offset
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
                  [ height bg bg-column ] if* yield ] map <flipped> concat
    concat
    <image> swap >>bitmap width height 2array >>dim
    ubyte-components >>component-type
    BGRA >>component-order ;


: alpha-color ( color alpha -- rgba )
    [ >rgba-components drop ] dip <rgba> ;

: clamp-index ( seq i -- i )
    swap length 1 - 0 swap clamp ;

: 0/ ( x y -- z ) [ drop 0 ] [ / ] if-zero ;

: fit-to-scale ( pref-dim image-dim -- n )
    [ [ first ] bi@ 0/ ] [ [ second ] bi@ 0/ ] 2bi
    min ;

: adjust-image-dim ( pref-dim image-dim -- dim )
    [ fit-to-scale ] [ n*v ] bi ;

: rm-r ( path -- )
    dup file-info directory?
    [ [ qualified-directory-files [ rm-r ] each ] [ delete-directory ] bi ]
    [ delete-file ] if ;

ERROR: not-an-empty-directory path ;
: ensure-empty-path ( path -- path )
    normalize-path dup dup exists?
    [ dup { [ file-info directory? ] [ directory-files empty? ] } 1&&
      [ drop ]
      [
          dup \ not-an-empty-directory boa { { "Overwrite Contents" t } } throw-restarts
          [ [ rm-r ] [ make-directories ] bi ] [ drop ] if
      ] if
    ] [ make-directories ] if ;

ERROR: file-exists path ;

: ensure-empty-file-in-path ( path -- path )
    normalize-path dup
    [ parent-directory make-directories ]
    [ dup exists?
      [ dup \ file-exists boa { { "Overwrite File" t } } throw-restarts
        [ delete-file ] [ drop ] if ]
      [ drop ] if
    ] bi ;

: rename-file-stem ( path new -- path )
    [ [ parent-directory ] [ file-extension ] bi ] dip
    swap [ "." prepend append ] when* append-path ;

: timestamp>filename-component ( timestamp -- string )
    [ { YYYY "-" MM "-" DD "-" hh "-" mm "-" ss } formatted ] with-string-writer ;
