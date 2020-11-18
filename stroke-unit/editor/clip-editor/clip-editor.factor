USING: accessors arrays assocs audio.player-gadget combinators controls
controls.animation images.sequence-viewer images.viewer kernel locals models
models.arrow models.arrow.smart namespaces sequences sequences.zipped
stroke-unit.clip-renderer stroke-unit.clips stroke-unit.util ui.gadgets
ui.gadgets.books ui.gadgets.buttons ui.gadgets.desks ui.gadgets.labels
ui.gadgets.packs ui.gestures ;

IN: stroke-unit.editor.clip-editor

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
