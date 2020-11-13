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

! PREDICATE: longlongattr < string 2 tail-slice* "ll" sequence= ;
! GENERIC: attr>number ( str -- number )
! M: longlongattr attr>number 2 head-slice* string>number ;

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

: clip-video-duration ( clip -- duration )
    clip-strokes
    [ [ stroke-segments ] map concat [ segment-time ] map-sum  ]
    [ dup length 1 >
        [ 2 <clumps> [ first2 inter-stroke-time ] map-sum ]
        [ drop 0 ] if
    ] bi + seconds ;

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

! * Clip view gadget
! Strokes viewer, slider for progress, play button
TUPLE: clip-editor < pack elements audio iplayer aplayer ;
! : load-audio ( clip -- audio/f )
    ! audio>> dup empty? [ drop f ]
    ! [ get-current-audio-folder prepend-path ogg>audio ] if ;

: clip-audio-player ( clip-model -- gadget/f )
    value>> load-audio dup [ <audio-player> ] when ;

: clip-image-player ( clip-model -- gadget )
    [ render-clip-frames ] <arrow> fps get <image-player> ;

: <clip-state> ( model model -- model )
    [| s1 s2 |
     { { [ s1 running? ] [ running ] }
       { [ s2 running? ] [ running ] }
       { [ s1 paused? ] [ paused ] }
       { [ s2 paused? ] [ paused ] }
       [ finished ]
     } cond
    ] <smart-arrow> ;

: clip-button-label ( state -- gadget )
    [ { running paused finished } { "⏸" "⯈" "⏮" } <zipped> at ] <arrow> <label-control> ;

: clip-start-playback ( clip -- )
    [ iplayer>> ] [ aplayer>> ] bi
    [ [ animation>> start-animation ] when* ] bi@ ;

: clip-pause-playback ( clip -- )
    [ iplayer>> ] [ aplayer>> ] bi
    [ [ animation>> stop-animation ] when* ] bi@ ;

: rewind-clip ( clip -- )
    [ iplayer>> ] [ aplayer>> ] bi
    [ [ animation>> rewind-animation ] when* ] bi@ ;

GENERIC: clip-button-press ( player state -- )
M: finished clip-button-press drop rewind-clip ;
M: running clip-button-press drop clip-pause-playback ;
M: paused clip-button-press drop clip-start-playback ;

:: clip-controls ( clip-player iplayer aplayer -- button )
    iplayer animation>> [ state>> ] [ model>> ] bi :> ( istate irange )
    aplayer [ animation>> [ state>> ] [ model>> ] bi ] [ istate irange ] if* :> ( astate arange )
    istate astate <clip-state> :> clip-state
    clip-state clip-button-label
    [ drop clip-player clip-state value>> clip-button-press
    ] <button> ;


! TODO: fix model hierarchy ( DOING )
:: <clip-editor> ( clip-model -- gadget )
    clip-editor new vertical >>orientation dup :> gadget
    ! clip <model> dup :>
    clip-model >>model
    clip-model clip-image-player dup :> iplayer [ >>iplayer ] [ add-gadget ] bi
    clip-model clip-audio-player :> aplayer
    aplayer [ [ >>aplayer ] keep ] [ <gadget> ] if* add-gadget
    dup iplayer aplayer clip-controls add-gadget ;

M: clip-editor hide-controls* [ call-next-method ] [ children>> last hide-gadget ] bi ;
M: clip-editor show-controls* [ call-next-method ] [ children>> last show-gadget ] bi ;

TUPLE: clip-viewer < book clip ;

: switch-to-preview ( x -- )
    model>> 0 swap set-model ;

: switch-to-editor ( x -- )
    model>> 1 swap set-model ;

: reset-clip-viewer ( gadget -- )
    children>> second rewind-clip ;

: play-clip-viewer ( gadget -- )
    [ switch-to-editor ]
    [ children>> second clip-start-playback ] bi ;

: <clip-preview> ( clip-model -- gadget )
    value>> clip-image <image-gadget> ;

! Does rendering at construction time because of dimensions for image.  Not cool, really
! : <clip-preview> ( clip-model -- gadget )
!     [ clip-image ] <arrow>
!     ! HACK: force dimensions for layouting
!     dup [ activate-model ] [ deactivate-model ] bi
!     <image-control> ;

:: <clip-viewer> ( clip -- gadget )
    clip <model> :> clip-model
    clip-model <clip-editor> :> editor
    ! editor iplayer>> model>> :> frames-model
    clip-model <clip-preview>
    ! frames-model [ last ] <arrow> <image-control>
    editor 2array 0 <model> clip-viewer new-book swap add-gadgets
    clip-model >>clip ;

! M: clip-viewer pref-rect* clip>> [ pref-rect* ] [ <zero-rect> ] if* ;
M: clip-viewer pref-loc* clip>> value>> elements>> pref-rect-loc-min ;
M: clip-viewer pref-rect* clip>> value>> elements>> pref-rect-union ;
M: clip-viewer pref-dim* current-page pref-dim* ;
! M: clip-viewer pref-dim* pref-rect* dim>> ;

SYMBOL: selected-clip

: selected? ( gadget -- ? )
    selected-clip get = ;

: make-selected ( gadget -- )
    selected-clip get [ switch-to-preview ] when*
    [ switch-to-editor ] [ selected-clip set ] bi ;

: clip-viewer-clicked ( clip-viewer -- )
    make-selected ;
    ! model>> 1 swap set-model ;
! : clip-viewer-leave ( clip-viewer -- ) model>> 0 swap set-model ;

! M: clip-viewer handles-gesture?
!     dup selected? [ 2drop f ] [ call-next-method ] if ;

clip-viewer H{
    { T{ button-up } [ clip-viewer-clicked ] }
    ! { mouse-enter [ clip-viewer-enter ] }
    ! { mouse-leave [ clip-viewer-leave ] }
} set-gestures

! TUPLE: clip-button < button clip ;

! TODO: wouldn't update, not dynamic
! :: <clip-button> ( clip quot -- button )
!     clip clip-image <image-gadget> quot clip-button new-button
!     clip >>clip ;

! : clip-player-controls ( clip -- button slider image-control )
!     clip-strokes <model> [ render-clip-frames ] <arrow> fps get <image-sequence-controls> ;

! :: <clip-viewer> ( clip -- gadget )
!     clip-editor new vertical >>orientation :> clipv
!     clip [ clip-player-controls ] [ clip-audio-player ] bi :> ( button slider imagev player )
!     audio [ [  ] ]


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
