USING: accessors arrays assocs audio.player-gadget calendar combinators controls
controls.animation images.sequence-viewer images.viewer io.pathnames kernel
locals math.rectangles models models.arrow models.arrow.smart namespaces
sequences sequences.zipped stroke-unit.clip-renderer stroke-unit.elements
stroke-unit.strokes stroke-unit.util timers ui.gadgets ui.gadgets.books
ui.gadgets.borders ui.gadgets.buttons ui.gadgets.desks ui.gadgets.labels
ui.gadgets.packs ui.gestures ui.pens.image xml.syntax ;

IN: stroke-unit.clips

TUPLE: clip ogg-file audio-path audio elements ;
: <clip> ( audio-path -- obj ) clip new swap >>audio-path V{ } clone >>elements ;

SYMBOL: current-clips
SINGLETON: +no-audio+

: with-current-clips ( quot -- )
    [ V{ } clone current-clips ] dip [
        +no-audio+ <clip> current-clips get push
    ] prepose with-variable ; inline

: current-audio ( -- audio )
    current-clips get last audio-path>> ;

: update-current-clip ( audio -- )
    current-audio 2dup =
    [ 2drop ]
    [ +no-audio+?
      [ current-clips get last audio-path<< ]
      [ ! f
          dup f =
          [ drop ]
          [ <clip> current-clips get push ] if
      ] if
    ] if ;

TAGS: change-clip ( elt -- )
TAG: stroke change-clip stroke-audio update-current-clip ;
TAG: image change-clip drop ;

: analyze-clips ( xml -- clips )
    [ pages [ layers [ strokes [
                           [ change-clip ] [ current-clips get last elements>> push ] bi
                       ] each ] each ] each
      current-clips get
    ] with-current-clips ;

! Adjusted for travel speed
: clip-move-distance ( clip -- pts )
    clip-strokes
    [ [ stroke-segments ] map concat [ segment-length ] map-sum  ]
    [ dup length 1 >
      [ 2 <clumps> [ first2 inter-stroke-length travel-speed-factor get * ] map-sum ]
      [ drop 0 ] if
    ] bi + ;

: clip-video-duration ( clip -- duration )
    clip-move-distance stroke-speed get /f ;
    ! clip-strokes
    ! [ [ stroke-segments ] map concat [ segment-time ] map-sum  ]
    ! [ dup length 1 >
    !     [ 2 <clumps> [ first2 inter-stroke-time ] map-sum ]
    !     [ drop 0 ] if
    ! ] bi + seconds ;

: load-audio ( clip -- ? )
    dup audio>> [ nip ] [
        dup audio-path>> dup empty? [ 2drop f ]
        [ get-current-audio-folder prepend-path ogg>audio
          >>audio audio>> ] if
    ] if* ;

: clip-audio-duration ( clip -- duration )
    load-audio [ audio-duration ] [ instant ] if* ;

: clip-duration ( clip -- duration )
    [ clip-video-duration ]
    [ clip-audio-duration ] bi max ;
