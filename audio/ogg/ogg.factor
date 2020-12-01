USING: accessors audio audio.engine audio.loader audio.vorbis byte-arrays
byte-vectors kernel math sequences threads ;

IN: audio.ogg

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
