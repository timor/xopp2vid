USING: accessors images.viewer kernel math math.order math.rectangles
math.vectors models models.arrow.smart namespaces stroke-unit.clip-renderer
stroke-unit.models.clip-display stroke-unit.util ui.gadgets
ui.gadgets.model-children ui.gadgets.wrappers.rect-wrappers ;

IN: stroke-unit.page.canvas

SYMBOL: preview-stroke-speed
preview-stroke-speed [ 70 <model> ] initialize

! * Cobbling together an image sequence viewer using models
! TODO: memoize this on a page cache
: scaled-clip-frames ( clip scale -- frames )
    scale-factor [ render-clip-frames ] with-variable ;

: <clip-preview-frames--> ( clip-model scale-model -- frames-model )
    preview-stroke-speed get [ stroke-speed [ scaled-clip-frames ] with-variable ]
    <?smart-arrow> ;

: <clip-rect--> ( clip-model scale-model -- rect-model )
    [ [ clip-rect ] dip rect-scale ] <?smart-arrow> ;

! Convention: times in seconds, durations in seconds
! TODO: see if there is better semantics for zero-duration clips
: (clip-position) ( time start-time duration -- position )
    0.01 max [ - ] dip / 0 1 clamp ;

: <clip-position--> ( time-model start-time-model duration-model -- position-model )
    [ (clip-position) ] <?smart-arrow> ;

: <frame-select--> ( image-seq-model time-model start-time-model duration-model -- element-model )
    <clip-position--> [ swap float-nth ] <smart-arrow> ;

: <clip-display-frames--> ( page-parameters clip-display -- image-seq-model )
    [ draw-scale>> ] [ clip-model>> ] bi* swap <clip-preview-frames--> ;

: <clip-view> ( page-parameters clip-display -- rect-model gadget )
    [ [ draw-scale>> ] [ clip-model>> ] bi* swap <clip-rect--> ]
    [ <clip-display-frames--> ]
    [ [ current-time>> ] [ [ start-time-model>> ] [ draw-duration-model>> ] bi ] bi* ]
    2tri <frame-select--> <image-control> ;

! Model: sequence of clip-displays
TUPLE: page-canvas < gadget parameters ;
INSTANCE: page-canvas model-children
M: page-canvas pref-dim*
    { 0 0 } swap [ rect-extent nip vmax ] each-child ;

: <positioned-clip-view> ( page-parameters clip-display -- gadget )
    <clip-view> <rect-wrapper> ;

M: page-canvas child-model>gadget
    parameters>> swap <positioned-clip-view> ;

M: page-canvas add-model-children swap add-gadgets ;

: <page-canvas> ( page-parameters clip-displays -- gadget )
    page-canvas new swap >>model
    swap >>parameters ;
