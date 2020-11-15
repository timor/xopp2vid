USING: accessors arrays calendar colors.constants combinators formatting
grouping images.viewer images.viewer.private kernel locals math math.order
math.rectangles math.vectors memoize models models.arrow models.arrow.smart
models.range namespaces opengl.textures sequences stroke-unit.clip-renderer
stroke-unit.models.clip-display stroke-unit.util ui.gadgets ui.gadgets.labels
ui.gadgets.packs ui.gadgets.sliders ui.gadgets.timeline ui.gadgets.tracks
ui.gadgets.wrappers.rect-wrappers ui.gestures ui.images ui.pens.solid ui.render
;

IN: stroke-unit.page

! * Cobbling together an image sequence viewer using models
! TODO: memoize this on a page cache
: scaled-clip-frames ( clip scale -- seq )
    scale-factor [ render-clip-frames ] with-variable ;

: <clip-frames--> ( clip-model scale-model stroke-speed-model -- image-seq-model )
    [ stroke-speed [ scaled-clip-frames ] with-variable ]
    <?smart-arrow> ;

: <clip-rect--> ( clip-model scale-model -- rect-model )
    [ [ clip-rect ] dip rect-scale ] <?smart-arrow> ;

! Convention: times in seconds, durations in durations
: <clip-position--> ( time-model start-time-model duration-model -- position-model )
    [ duration>seconds [ - ] dip / 0 1 clamp ] <?smart-arrow> ;

: <frame-select--> ( image-seq-model time-model start-time-model duration-model -- element-model )
    <clip-position--> [ swap float-nth ] <smart-arrow> ;

! All slots models
TUPLE: page-parameters current-time draw-scale time-scale ;
: <page-parameters> ( -- obj )
    0 <model> 1 <model> 10 <model> page-parameters boa ;

: recompute-page-duration ( clip-diplays -- seconds )
    last [ start-time>> compute-model ]
    [ draw-duration>> compute-model duration>seconds ] bi + ;
    ! [ draw-duration>> compute-model duration>seconds ]
    ! map-sum ;

: <range-page-parameters> ( clip-displays -- range-model parameters )
    recompute-page-duration [ 0 0 0 ] dip 0 <range>
    dup range-model 1 <model> 10 <model> page-parameters boa ;

: <clip-display-frames--> ( page-parameters clip-display -- image-seq-model )
    [ draw-scale>> ] [ [ clip>> ] [ stroke-speed>> ] bi ] bi* swapd <clip-frames--> ;

: <clip-view> ( page-parameters clip-display -- rect-model gadget )
    [ [ draw-scale>> ] [ clip>> ] bi* swap <clip-rect--> ]
    [ <clip-display-frames--> ]
    [ [ current-time>> ] [ [ start-time>> ] [ draw-duration>> ] bi ] bi* ]
    2tri <frame-select--> <image-control> ;

! Initial, assume default stroke speed, return sequence of clip-display models
: initialize-clips ( clips -- seq )
    stroke-speed get
    [ <clip-display> ] curry map
    dup 2 <clumps> [ first2 connect-clip-displays ] each ;

TUPLE: page-canvas < gadget parameters clip-displays ;
M: page-canvas pref-dim*
    { 0 0 } swap [ rect-extent nip vmax ] each-child ;

: init-page-gadgets ( page-canvas -- )
    dup [ parameters>> ] [ clip-displays>> ] bi
    [ <clip-view> <rect-wrapper> ] with map
    add-gadgets drop ;

: <page-canvas> ( page-parameters clip-displays -- gadget )
    page-canvas new swap >>clip-displays
    swap >>parameters
    dup init-page-gadgets ;

! * Viewer, includes canvas and controls
: <page-slider> ( range-model -- gadget )
    horizontal <slider> fps get recip >>line ;

! * Image-control that keeps aspect ratio and displays other stuff for use in timeline
TUPLE: clip-timeline-preview < image-control clip-display ;
<PRIVATE
: adjust-image-dim ( pref-dim image-dim -- dim )
    [ [ [ first ] bi@ / ] [ [ second ] bi@ / ] 2bi
      min ] [ n*v ] bi ;
PRIVATE>
M: clip-timeline-preview draw-gadget*
    dup image>>
    [ [ [ image-gadget-texture ] [ dim>> ] bi ]
      [ image-dim adjust-image-dim ] bi*
      swap draw-scaled-texture ]
    [ drop ] if* ;

SYMBOL: focused-clip-display
MEMO: preview-pen ( -- pen )
    COLOR: red <solid> ;

: preview-gain-focus ( gadget -- )
    [ preview-pen >>boundary relayout-1 ]
    [ clip-display>> focused-clip-display set ] bi ;

: preview-lose-focus ( gadget -- )
    f >>boundary relayout-1 ;

: <preview-position--> ( current-time clip-display -- model )
    [ start-time>> ] [ draw-duration>> ] bi
    [ duration>seconds [ - ] dip /
      dup 0 1 between? [ drop f ] unless
    ] <?smart-arrow> ;

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

! ** Clip preview gadgets in the timeline
: <clip-timeline-preview> ( current-time clip-display -- gadget )
    {
        [ clip>> [ clip-image ] <arrow> clip-timeline-preview new-image-gadget* ]
        [ >>clip-display ]
        [ draw-duration>> [ duration>seconds "%.1fs" sprintf ] <?arrow> <label-control> add-gadget ]
        [ swapd <preview-cursor> add-gadget ]
    } cleave ;

! * Editor, includes editable timeline
! Model is the current time
TUPLE: clip-timeline < timeline clip-displays ;

: focused-clip-index ( timeline -- i )
    clip-displays>> focused-clip-display get swap index ;

: focus-clip-index ( timeline i -- )
    swap children>> ?nth [ request-focus ] when* ;

: timeline-focus-left ( timeline -- ) dup focused-clip-index 1 - focus-clip-index ;

: timeline-focus-right ( timeline -- ) dup focused-clip-index 1 + focus-clip-index ;

clip-timeline H{
    { T{ key-down f f "h" } [ timeline-focus-left ] }
    { T{ key-down f f "l" } [ timeline-focus-right ] }
} set-gestures

:: <page-timeline> ( page-parameters clip-displays -- gadget )
    5 10 horizontal clip-timeline new-timeline clip-displays [ >>clip-displays ] keep
    [ [ page-parameters current-time>> swap <clip-timeline-preview> ] [ draw-duration>> ] bi timeline-add ] each ;

: <page-editor> ( clip-displays -- gadget )
    vertical <track> swap
    [ <range-page-parameters> ] keep
    rot
    [
        [ <page-canvas> 0.85 track-add ]
        [ <page-timeline> 0.15 track-add ] 2bi
    ] dip
    <page-slider> f track-add
    ;
