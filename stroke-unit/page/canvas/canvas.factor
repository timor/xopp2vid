USING: accessors assocs calendar hashtables.identity images.viewer kernel locals
math math.order math.rectangles math.vectors models models.arrow.smart
namespaces sequences stroke-unit.clip-renderer stroke-unit.clips
stroke-unit.models.clip-display stroke-unit.util ui.gadgets
ui.gadgets.wrappers.rect-wrappers ;

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

! Convention: times in seconds, durations in durations
! TODO: see if there is better semantics for zero-duration clips
: (clip-position) ( time start-time duration -- position )
    duration>seconds 0.01 max [ - ] dip / 0 1 clamp ;

: <clip-position--> ( time-model start-time-model duration-model -- position-model )
    [ (clip-position) ] <?smart-arrow> ;

: <frame-select--> ( image-seq-model time-model start-time-model duration-model -- element-model )
    <clip-position--> [ swap float-nth ] <smart-arrow> ;

: <clip-display-frames--> ( page-parameters clip-display -- image-seq-model )
    [ draw-scale>> ] [ clip>> ] bi* swap <clip-preview-frames--> ;

: <clip-view> ( page-parameters clip-display -- rect-model gadget )
    [ [ draw-scale>> ] [ clip>> ] bi* swap <clip-rect--> ]
    [ <clip-display-frames--> ]
    [ [ current-time>> ] [ [ start-time>> ] [ draw-duration>> ] bi ] bi* ]
    2tri <frame-select--> <image-control> ;

! Model: sequence of clip-displays
TUPLE: page-canvas < gadget parameters ;
M: page-canvas pref-dim*
    { 0 0 } swap [ rect-extent nip vmax ] each-child ;

! Cache preview and view gadgets
SYMBOL: clip-view-cache
clip-view-cache [ IH{ } clone ] initialize

: <positioned-clip-view> ( page-parameters clip-display -- gadget )
    <clip-view> <rect-wrapper> ;

:: find-clip-view ( page-parameters clip-display -- gadget )
    clip-display clip-view-cache get
    [ [ page-parameters ] dip <positioned-clip-view> ] cache ;

: synchronize-views ( gadget clip-displays -- )
    [ clip>> compute-model empty-clip? ] reject
    over [ clear-gadget ] [ parameters>> ] bi
    swap [ find-clip-view ] with map add-gadgets drop ;

M: page-canvas model-changed
    swap value>> [ synchronize-views ] keepd relayout ;

: <page-canvas> ( page-parameters clip-displays -- gadget )
    page-canvas new swap >>model
    swap >>parameters ;
! dup init-page-gadgets ;
