USING: accessors audio.gadget cairo-gadgets cairo.ffi images.sequence-viewer
io.pathnames kernel math namespaces sequences stroke-unit.clip-renderer
stroke-unit.elements stroke-unit.strokes stroke-unit.util ui.gadgets
ui.gadgets.packs ui.gadgets.tracks xml.syntax ;

IN: stroke-unit.clips

TUPLE: clip ogg-file audio elements ;
: <clip> ( audio -- obj ) clip new swap >>audio V{ } clone >>elements ;

SYMBOL: current-clips
SINGLETON: +no-audio+

: with-current-clips ( quot -- )
    [ V{ } clone current-clips ] dip [
        +no-audio+ <clip> current-clips get push
    ] prepose with-variable ; inline

! PREDICATE: longlongattr < string 2 tail-slice* "ll" sequence= ;
! GENERIC: attr>number ( str -- number )
! M: longlongattr attr>number 2 head-slice* string>number ;

: current-audio ( -- audio )
    current-clips get last audio>> ;

: update-current-clip ( audio -- )
    current-audio 2dup =
    [ 2drop ]
    [ +no-audio+?
      [ current-clips get last audio<< ]
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


! * Clip view gadget
! Strokes viewer, slider for progress, play button
TUPLE: clip-viewer < pack elements ;
: load-audio ( clip -- audio/f )
    audio>> dup empty? [ drop f ]
    [ get-current-audio-folder prepend-path ogg>audio ] if ;

: clip-audio-gadget ( clip -- gadget/f )
    load-audio dup [ <audio-gadget> ] when ;

: clip-player-gadget ( clip -- gadget )
    clip-strokes fps get <image-player> ;

! :: <clip-viewer> ( clip -- gadget )
!     clip-player-gadget :> player
    ! clip-audio-gadget :> audio



! : add-frame-slider ( gadget clip )

! : <clip-viewer> ( clip -- gadget )
!     <pile> swap
!     [ elements>> <cairo-renderer> [ >>elements ] [ add-gadget ] bi* ]
!     [ <shelf> swap [ maybe-add-audio-gadget ] [  ] ]

! TUPLE: strokes-container ;

! M: strokes-container pref-rect*
!     children>> [ pref-dim ] [ rect-union ] map-reduce ;

! TUPLE: clip-strokes-gadget < cairo-image-gadget strokes ;
! : <clip-strokes-gadget> ( clip -- obj )
!     clip-strokes-gadget new
!     swap elements>> [ stroke-element? ] filter >>strokes ;

! M: clip-strokes-gadget pref-dim*
!     strokes>> strokes-dim ;

! M: clip-strokes-gadget render-cairo* strokes>>
!     [ [ strokes-rect loc>>
!         cr swap first2 [ neg ] bi@ cairo_translate ]
!     [ [ draw-stroke ] each ] bi ] with-saved-cairo-matrix ;

! : <clip-gadget> ( clip -- gadget )
!     <shelf> swap
!     [ <clip-strokes-gadget> add-gadget ] [ load-audio [ <audio-gadget> add-gadget ] when* ] bi ;


! : <clip-list> ( clips -- gadget )
!     vertical <track> swap [ <clip-gadget> f track-add ] each ;


! : ensure-clip ( -- )
!     current-clips get empty?
!     [ last-audio-file get <clip> current-clips get push ] when ;

! M: stroke change-clip  stroke-clip-info drop update-current-clip ;
! M: stroke change-clip audio>> update-current-clip ;
! M: image-elt change-clip drop ;
