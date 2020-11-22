USING: accessors arrays audio audio.player-gadget colors.constants combinators
continuations formatting images images.viewer images.viewer.private io.pathnames
kernel math math.order math.rectangles models models.arrow models.arrow.smart
models.async models.selection opengl.textures sequences
stroke-unit.clip-renderer stroke-unit.clips stroke-unit.util ui.gadgets
ui.gadgets.labels ui.gadgets.model-children ui.gadgets.scrollers
ui.gadgets.timeline ui.gadgets.wrappers.rect-wrappers ui.gestures ui.pens.solid
ui.render ;

IN: stroke-unit.page.clip-timeline

! * Image-control that keeps aspect ratio and displays other stuff for use in timeline
TUPLE: clip-timeline-preview < image-control clip-display ;
M: clip-timeline-preview draw-gadget*
    dup image>>
    [ [ [ image-gadget-texture ] [ dim>> ] bi ]
      [ images:image-dim adjust-image-dim ] bi*
      swap draw-scaled-texture ]
    [ drop ] if* ;

MEMO: preview-pen ( -- pen )
    COLOR: red <solid> ;

: layout-selected ( gadget ? -- )
    preview-pen f ? >>boundary
    relayout ;

DEFER: find-timeline
M: clip-timeline-preview selection-index
    [ find-timeline children>> ] keep
    [ child? ] curry find drop ;

: preview-gain-focus ( gadget -- )
    [ [ dim>> { 0 0 } swap <rect> ] keep scroll>rect ]
    [ t layout-selected ]
    [ notify-selection ] tri ;

: preview-lose-focus ( gadget -- )
    f layout-selected ;

: <preview-position--> ( current-time clip-display -- model )
    [ start-time-model>> ] [ draw-duration-model>> ] bi
    [ 0.01 max [ - ] dip /
      dup 0 1 between? [ drop f ] unless
    ] <?smart-arrow> ;

M: clip-timeline-preview ungraft*
    [ call-next-method ]
    [ f layout-selected ] bi ;

:: compute-audio-clip ( current-time start-time clip -- delay clip/f )
    clip load-audio
    [ :> audio
      audio audio-duration :> duration
      current-time start-time duration + >
      [ 0 f ]
      [ start-time current-time - 0 max
        current-time start-time - 0 max audio make-offset-clip ] if
    ] [ 0 f ] if* ;

! Model: preview-position
TUPLE: preview-cursor < gadget ;
: cursor-rect ( gadget position -- rect )
    [ parent>> ] dip
    [ [ dim>> first ] dip * 0 2array ]
    [ drop dim>> second 1 swap 2array ] 2bi <rect> ; inline

M: preview-cursor model-changed
    [ swap value>>
      [ [ show-gadget ] [ hide-gadget ] if ]
      [ [ dupd cursor-rect rect-bounds [ >>loc ] [ >>dim ] bi* drop ] [ drop ] if* ] 2bi ]
    keep parent>> relayout-1 ;

: <preview-cursor> ( current-time clip-display -- gadget )
    <preview-position--> preview-cursor new swap >>model
    COLOR: blue <solid> >>interior ;

clip-timeline-preview H{
    { gain-focus [ preview-gain-focus ] }
    { lose-focus [ preview-lose-focus ] }
    { T{ button-down } [ request-focus ] }
} set-gestures

MEMO: <empty-image> ( -- image )
    <image> { 0 0 } >>dim
    L >>component-order
    ubyte-components >>component-type
    B{ } >>bitmap ;
    ! { { 1 } } matrix>image ;
! ** Audio clip previews

: maybe-load-audio ( clip -- audio/path ? )
    [ load-audio t ] [ drop audio-path>> f ] recover
    over audio? [ drop f ] unless ;

: <clip-audio-image--> ( clip-model -- image-model )
    [
        maybe-load-audio
        [ 0 500 20 COLOR: blue 0.6 alpha-color COLOR: blue 0.2 alpha-color audio-image ]
        [ drop <empty-image> ] if
    ] <empty-image> <arrow&> ;

: <audio-indicator> ( timescale clip-display -- gadget )
    clip-model>> [ [ clip-audio-duration * 20 2array { 0 50 } swap <rect> ] <?smart-arrow> ] keep
    <clip-audio-image--> <image-control> <rect-wrapper> ;

! ** Clip preview gadgets in the timeline

: <clip-parameter-string--> ( clip-display -- str )
    {
        [ start-time-model>> ]
        [ draw-duration-model>> ]
        [ stroke-speed-model>> ]
        [ clip-model>> ]
    } cleave
    [ [ ] 2dip audio-path>> dup +no-audio+? [ drop "" ] [ file-name ] if "%.1fs\n+%.1fs\n%.1fpt/s\n\n\n\n%-30s" sprintf ] <?smart-arrow> ;

GENERIC: <clip-preview-image> ( model clip -- gadget )

M: stroke-unit.clips:clip <clip-preview-image>
    drop [ clip-image ] <arrow> clip-timeline-preview new-image-gadget* ;
M: empty-clip <clip-preview-image> 2drop <empty-image> clip-timeline-preview new-image-gadget* ;

: <clip-timeline-preview> ( page-parameters clip-display -- gadget )
    {
        [ clip-model>> dup compute-model <clip-preview-image> ]
        [ >>clip-display ]
        [ <clip-parameter-string--> <label-control> add-gadget ]
        ! [ draw-duration>> [ "%.1fs" sprintf ] <?arrow> <label-control> add-gadget ]
        [ pick current-time>> swap <preview-cursor> add-gadget ]
        [ swapd [ timescale>> ] dip
          <audio-indicator> add-gadget
          ! 2drop
        ]
    } cleave ;

! ** Clip Preview Timeline

! Model: sequence of clip-displays
TUPLE: clip-timeline < timeline parameters ;
INSTANCE: clip-timeline model-children

: focus-clip-index ( timeline i -- )
    swap children>> ?nth [ request-focus ] when* ;

: find-timeline ( gadget -- gadget/f )
    [ clip-timeline? ] find-parent ;

M: clip-timeline child-model>gadget
    parameters>> swap <clip-timeline-preview> ;

M: clip-timeline add-model-children
    swap [ dup clip-display>> draw-duration-model>> timeline-add ] each ;

:: <page-timeline> ( page-parameters clip-displays -- gadget )
    5 10 horizontal clip-timeline new-timeline
    clip-displays >>model
    page-parameters >>parameters ;

clip-timeline H{  } set-gestures
