USING: accessors cairo.surface-renderer calendar images.viewer kernel locals
math math.functions math.order math.rectangles models models.arrow.smart
namespaces sequences stroke-unit.clip-renderer stroke-unit.clips
stroke-unit.util ui.gadgets ui.gadgets.wrappers xml.traversal ;

IN: stroke-unit.page
FROM: ui.gadgets.wrappers => wrapper ;

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

! For updating display from speed parameter
: clip-draw-duration ( clip stroke-speed -- duration )
    [ clip-move-distance ] dip / seconds ;

: <draw-duration--> ( clip-display -- duration-model )
    [ clip>> ] [ stroke-speed>> ] bi
    [ clip-draw-duration ] <smart-arrow> ;

! Convention: times in seconds, durations in durations
! : <clip-time--> ( time-model start-time-model -- time-model )
!     [ - ] <smart-arrow> ;
! f is valid between 0.0 and 1.0
: float-nth ( f seq -- elt )
    [ 0 1 clamp ] dip
    [ length 1 - * floor >integer ]
    [ nth ] bi ; inline

: <frame-select--> ( image-seq-model time-model start-time-model duration-model -- element-model )
    [ duration>seconds [ - ] dip / swap float-nth ] <smart-arrow> ;

! All slots models
TUPLE: page-parameters current-time scale ;
: <page-parameters> ( -- obj )
    0 <model> 1 <model> page-parameters boa ;
: <range-page-parameters> ( clips )

: <clip-display-frames--> ( page-parameters clip-display -- image-seq-model )
    [ scale>> ] [ [ clip>> ] [ stroke-speed>> ] bi ] bi* swapd <clip-frames--> ;

: <clip-view> ( page-parameters clip-display -- rect-model gadget )
    [ [ scale>> ] [ clip>> ] bi* swap <clip-rect--> ]
    [ <clip-display-frames--> ]
    [ [ current-time>> ] [ [ start-time>> ] [ <draw-duration--> ] bi ] bi* ]
    2tri <frame-select--> <image-control> ;

: <clip-display> ( clip start-time stroke-speed -- obj )
    [ duration>seconds ] dip [ <model> ] tri@ clip-display boa ;

! Initial, assume default stroke speed, return sequence of clip-display models
:: initialize-clips ( clips -- seq )
    instant
    stroke-speed get :> speed
    clips [| clip | clip speed clip-draw-duration [ time+ ] keepd
    clip swap speed <clip-display> ] map nip ;

! Model: it's own dim and loc
TUPLE: rect-wrapper < wrapper ;
M: rect-wrapper model-changed
    [ value>> rect-bounds ] dip
    [ [ dim<< ] [ loc<< ] bi ] [ relayout ] bi ;
M: rect-wrapper pref-dim*
    model>> compute-model dim>> ;
! M: rect-wrapper layout*
!     [ call-next-method ]
!     [ gadget-child ] [ loc>> ] [  ]

: <rect-wrapper> ( model gadget -- gadget )
    rect-wrapper new-wrapper swap >>model ;

TUPLE: page-canvas < gadget parameters clip-displays ;
M: page-canvas pref-dim*
    { 0 0 } swap [ rect-extent nip vmax ] each-child ;

: init-page-gadgets ( page-canvas -- )
    dup [ parameters>> ] [ clip-displays>> ] bi
    [ <clip-view> <rect-wrapper> ] with map
    add-gadgets drop ;

: <page-canvas> ( clips -- gadget time-range )
    page-canvas new swap initialize-clips >>clip-displays
    <page-parameters> >>parameters
    dup init-page-gadgets ;

! * Viewer, includes canvas and controls
: <page-viewer> ( clips -- gadget )
    vertical <track> swap
    [  ]






! : <page-gadget> ( page -- gadget )
!     <cairo-surface-gadget> swap
!     "stroke" deep-tags-named [ <stroke-gadget> add-gadget ] each ;
SLOT: elements
TUPLE: page-renderer model gadget ;

: <page-renderer> ( page -- obj )
    "layer" tags-named [ children-tags ] map concat
    <cairo-renderer> page-renderer boa ;

M: page-renderer elements<< model>> set-model ;

