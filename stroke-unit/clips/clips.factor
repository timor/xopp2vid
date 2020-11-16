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
: strokes-move-distance ( strokes -- l )
    [ [ stroke-segments ] map concat [ segment-length ] map-sum  ]
    [ dup length 1 >
      [ 2 <clumps> [ first2 inter-stroke-length travel-speed-factor get * ] map-sum ]
      [ drop 0 ] if
    ] bi + ;

: clip-move-distance ( clip -- pts )
    clip-strokes strokes-move-distance ;

: clip-video-duration ( clip -- duration )
    clip-move-distance stroke-speed get /f ;

! position is between 0.0 and 1.0
! TODO: candidate for caching if needed
: clip-find-offset-stroke ( clip position -- stroke )
    [ clip-strokes dup ] dip
    over strokes-move-distance *
    swap dup length <iota> [ 1 + head-slice strokes-move-distance ] with <map>
    natural-search drop swap nth ;

! * Splitting

! Create new clips with subsets of elements before and after position
: clip-split-at ( clip position -- clip-before clip-after )
    [ clone dup ] dip clip-find-offset-stroke
    over elements>> [ index ] keep swap cut-slice
    [ >>elements ] [ [ dup clone ] dip >>elements ] bi* ;

! * Audio

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
