USING: accessors cairo cairo-gadgets cairo.ffi classes.struct images.viewer audio.engine audio.vorbis
kernel locals namespaces sequences ui.render urls xml xml.data xml.traversal ;

IN: stroke-unit.util

SYMBOL: current-audio-folder

: get-current-audio-folder ( -- path )
    current-audio-folder
    [ [ "~/.xournalpp/settings.xml" normalize-path file>xml
        "property" tags-named [ "name" attr "audioFolder" = ] find nip
        [ "value" attr "file://" drop-prefix drop >string ] [ f ] if*
      ] unless* ] change
    current-audio-folder get ;

TUPLE: cairo-image-gadget < image-gadget ;

M:: cairo-image-gadget draw-gadget* ( gadget -- )
    gadget dup dim>> [
        current-cairo set
        gadget render-cairo*
    ] make-bitmap-image >>image
    call-next-method ;

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