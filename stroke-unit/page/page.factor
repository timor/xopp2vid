USING: accessors calendar images.viewer kernel locals math math.functions
math.order math.rectangles math.vectors models models.arrow.smart models.range
namespaces sequences stroke-unit.clip-renderer stroke-unit.clips
stroke-unit.util ui.gadgets ui.gadgets.packs ui.gadgets.sliders ;

IN: stroke-unit.page

! * Cobbling together an image sequence viewer using models
! TODO: memoize this on a page cache
: scaled-clip-frames ( clip scale -- seq )
    scale-factor [ render-clip-frames ] with-variable ;

: <clip-frames--> ( clip-model scale-model stroke-speed-model -- image-seq-model )
    [ stroke-speed [ scaled-clip-frames ] with-variable ]
    <smart-arrow> ;

: <clip-rect--> ( clip-model scale-model -- rect-model )
    [ [ clip-rect ] dip rect-scale ] <smart-arrow> ;

! These are all models
TUPLE: clip-display clip start-time stroke-speed draw-duration ;

! For adjusting duration from ui controls
: <draw-speed--> ( duration-model clip-model -- speed-model )
    [ [ duration>seconds ] [ clip-move-distance ] bi* swap / ]
    <smart-arrow> ;

: clip-draw-duration ( clip stroke-speed -- duration )
    [ clip-move-distance ] dip / seconds ;

! For updating display from speed parameter
: <draw-duration--> ( clip-model stroke-speed-model -- duration-model )
    [ clip-draw-duration ] <smart-arrow> ;

! Convention: times in seconds, durations in durations
: <clip-position--> ( time-model start-time-model duration-model -- position-model )
    [ duration>seconds [ - ] dip / 0 1 clamp ] <?smart-arrow> ;

! f is valid between 0.0 and 1.0
: float-nth ( f seq -- elt )
    [ 0 1 clamp ] dip
    [ length 1 - * floor >integer ]
    [ nth ] bi ; inline

! TODO: make intermediate model for clip-time which does not update if out of bounds
: <frame-select--> ( image-seq-model time-model start-time-model duration-model -- element-model )
    <clip-position--> [ swap float-nth ] <smart-arrow> ;

! All slots models
TUPLE: page-parameters current-time scale ;
: <page-parameters> ( -- obj )
    0 <model> 1 <model> page-parameters boa ;

: recompute-page-duration ( clip-diplays -- seconds )
    [ draw-duration>> compute-model duration>seconds ]
    map-sum ;

: <range-page-parameters> ( clip-displays -- range-model obj )
    recompute-page-duration [ 0 0 0 ] dip 0 <range>
    dup range-model 1 <model> page-parameters boa ;

: <clip-display-frames--> ( page-parameters clip-display -- image-seq-model )
    [ scale>> ] [ [ clip>> ] [ stroke-speed>> ] bi ] bi* swapd <clip-frames--> ;

: <clip-view> ( page-parameters clip-display -- rect-model gadget )
    [ [ scale>> ] [ clip>> ] bi* swap <clip-rect--> ]
    [ <clip-display-frames--> ]
    [ [ current-time>> ] [ [ start-time>> ] [ draw-duration>> ] bi ] bi* ]
    2tri <frame-select--> <image-control> ;

: <clip-display> ( clip start-time stroke-speed -- obj )
    [ duration>seconds ] dip [ <model> ] tri@
    3dup nip <draw-duration-->
    clip-display boa ;

! Initial, assume default stroke speed, return sequence of clip-display models
:: initialize-clips ( clips -- seq )
    instant
    stroke-speed get :> speed
    clips [| clip | clip speed clip-draw-duration [ time+ ] keepd
    clip swap speed <clip-display> ] map nip ;

TUPLE: page-canvas < gadget parameters clip-displays ;
M: page-canvas pref-dim*
    { 0 0 } swap [ rect-extent nip vmax ] each-child ;

: init-page-gadgets ( page-canvas -- )
    dup [ parameters>> ] [ clip-displays>> ] bi
    [ <clip-view> <rect-wrapper> ] with map
    add-gadgets drop ;

: <page-canvas> ( clips -- seconds-range gadget )
    page-canvas new swap initialize-clips [ >>clip-displays ] keep
    <range-page-parameters> swapd >>parameters
    dup init-page-gadgets ;

! * Viewer, includes canvas and controls
: <page-viewer> ( clips -- gadget )
    <page-canvas>
    <filled-pile> swap add-gadget
    swap horizontal <slider> fps get recip >>line add-gadget ;
