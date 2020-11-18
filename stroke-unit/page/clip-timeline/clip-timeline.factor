USING: accessors arrays assocs audio.player-gadget calendar colors.constants
combinators formatting hashtables.identity images images.viewer
images.viewer.private kernel locals math math.order math.rectangles math.vectors
memoize models models.arrow models.arrow.smart models.async namespaces
opengl.textures sequences stroke-unit.clip-renderer stroke-unit.clips
stroke-unit.models.page-parameters stroke-unit.util ui.gadgets ui.gadgets.labels
ui.gadgets.scrollers ui.gadgets.timeline ui.gadgets.wrappers.rect-wrappers
models.selection
ui.gestures ui.pens.solid ui.render ;

IN: stroke-unit.page.clip-timeline

! * Image-control that keeps aspect ratio and displays other stuff for use in timeline
TUPLE: clip-timeline-preview < image-control clip-display ;
<PRIVATE
: 0/ ( x y -- z ) [ drop 0 ] [ / ] if-zero ;
: adjust-image-dim ( pref-dim image-dim -- dim )
    [ [ [ first ] bi@ 0/ ] [ [ second ] bi@ 0/ ] 2bi
      min ] [ n*v ] bi ;
PRIVATE>
M: clip-timeline-preview draw-gadget*
    dup image>>
    [ [ [ image-gadget-texture ] [ dim>> ] bi ]
      [ images:image-dim adjust-image-dim ] bi*
      swap draw-scaled-texture ]
    [ drop ] if* ;

MEMO: preview-pen ( -- pen )
    COLOR: red <solid> ;

! IN: stroke-unit.page
! DEFER: find-page-parameters
! DEFER: set-focus-index
! IN: stroke-unit.page.clip-timeline

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


    ! dup clip-display>> notify-selection ;

    ! [ preview-pen >>boundary relayout-1 ]
    ! [ dup clip-display>> set-focus-index ]
    ! [ [ dim>> { 0 0 } swap <rect> ] keep scroll>rect ]
    ! tri ;

: preview-lose-focus ( gadget -- )
    f layout-selected ;
    ! f >>boundary relayout-1 ;

: <preview-position--> ( current-time clip-display -- model )
    [ start-time>> ] [ draw-duration>> ] bi
    [ duration>seconds 0.01 max [ - ] dip /
      dup 0 1 between? [ drop f ] unless
    ] <?smart-arrow> ;

M: clip-timeline-preview ungraft*
    [ call-next-method ]
    [ f layout-selected ] bi ;

:: compute-audio-clip ( current-time start-time clip -- delay clip/f )
    clip load-audio
    [ :> audio
      audio audio-duration duration>seconds :> duration
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

! : <audio-indicator> ( timescale clip-display -- gadget )
!     clip>> [ clip-audio-duration duration>seconds * 10 2array { 0 50 } swap <rect> ] <?smart-arrow>
!     <gadget> COLOR: blue 0.2 alpha-color <solid> >>interior <rect-wrapper> ;

: <clip-audio-image--> ( clip-model -- image-model )
    [
        load-audio
        [ 0 500 20 COLOR: blue 0.6 alpha-color COLOR: blue 0.2 alpha-color audio-image ]
        [ <empty-image> ] if*
    ] <empty-image> <arrow&> ;

: <audio-indicator> ( timescale clip-display -- gadget )
    clip>> [ [ clip-audio-duration duration>seconds * 20 2array { 0 50 } swap <rect> ] <?smart-arrow> ] keep
    <clip-audio-image--> <image-control> <rect-wrapper> ;

! ** Clip preview gadgets in the timeline

: <clip-parameter-string--> ( clip-display -- str )
    [ start-time>> ]
    ! [ draw-duration>> ]
    [ stroke-speed>> ] bi
    [ "%.1fs\n%.1fpt/s" sprintf ] <?smart-arrow> ;

GENERIC: <clip-preview-image> ( model clip -- gadget )

M: stroke-unit.clips:clip <clip-preview-image>
    drop [ clip-image ] <arrow> clip-timeline-preview new-image-gadget* ;
M: empty-clip <clip-preview-image> 2drop <empty-image> clip-timeline-preview new-image-gadget* ;

: <clip-timeline-preview> ( page-parameters clip-display -- gadget )
    {
        [ clip>> dup compute-model <clip-preview-image> ]
        [ >>clip-display ]
        [ <clip-parameter-string--> <label-control> add-gadget ]
        ! [ draw-duration>> [ duration>seconds "%.1fs" sprintf ] <?arrow> <label-control> add-gadget ]
        [ pick current-time>> swap <preview-cursor> add-gadget ]
        [ swapd [ timescale>> ] dip
          <audio-indicator> add-gadget
          ! 2drop
        ]
    } cleave ;

! ** Clip Preview Timeline

! Model: sequence of clip-displays
TUPLE: clip-timeline < timeline ;

: focus-clip-index ( timeline i -- )
    swap children>> ?nth [ request-focus ] when* ;

: find-timeline ( gadget -- gadget/f )
    [ clip-timeline? ] find-parent ;

! : when-focus ( quot: ( index -- ) -- )
!     focused-clip-index get 0 or swap call ; inline

! : timeline-focus-left ( timeline -- ) [ swap 1 - focus-clip-index ] curry when-focus ;

! : timeline-focus-right ( timeline -- ) [ swap 1 + focus-clip-index ] curry when-focus ;

SYMBOL: clip-preview-cache
clip-preview-cache [ IH{ } clone ] initialize

:: find-timeline-preview ( page-parameters clip-display -- gadget )
    clip-display clip-preview-cache get
    [ [ page-parameters ] dip <clip-timeline-preview> ] cache ;

IN: stroke-unit.page
DEFER: find-page-parameters
IN: stroke-unit.page.clip-timeline
: synchronize-previews ( gadget clip-displays -- )
    over [ clear-gadget ] [ find-page-parameters ] bi
    swap [ [ find-timeline-preview ] [ draw-duration>> ] bi timeline-add ] with each drop ;

M: clip-timeline model-changed
    swap value>> [ synchronize-previews ] keepd relayout ;

:: <page-timeline> ( clip-displays -- gadget )
    20 10 horizontal clip-timeline new-timeline
    clip-displays >>model ;

clip-timeline H{  } set-gestures
