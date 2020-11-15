USING: accessors calendar formatting grouping images.viewer
images.viewer.private kernel math math.order math.rectangles math.vectors models
models.arrow models.arrow.smart models.range namespaces opengl.textures
sequences stroke-unit.clip-renderer stroke-unit.models.clip-display
stroke-unit.util ui.gadgets ui.gadgets.labels ui.gadgets.packs
ui.gadgets.sliders ui.gadgets.timeline ui.gadgets.tracks
ui.gadgets.wrappers.rect-wrappers ui.images ui.render ;

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
TUPLE: page-parameters current-time scale ;
: <page-parameters> ( -- obj )
    0 <model> 1 <model> page-parameters boa ;

: recompute-page-duration ( clip-diplays -- seconds )
    last [ start-time>> compute-model ]
    [ draw-duration>> compute-model duration>seconds ] bi + ;
    ! [ draw-duration>> compute-model duration>seconds ]
    ! map-sum ;

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


! : <end-time--> ( prev-end-time-model duration-model -- time-model )
!     [ time+ ] <?smart-arrow> ;

    ! [ duration>seconds ] dip [ <model> ] tri@
    ! 3dup nip <draw-duration-->
    ! [ f ] 4 ndip clip-display boa ;

! Initial, assume default stroke speed, return sequence of clip-display models
: initialize-clips ( clips -- seq )
    stroke-speed get
    [ <clip-display> ] curry map
    dup 2 <clumps> [ first2 connect-clip-displays ] each ;
    ! clips [| clip | clip speed clip-draw-duration [ time+ ] keepd
    ! clip swap speed <clip-display> ] map nip ;

TUPLE: page-canvas < gadget parameters clip-displays ;
M: page-canvas pref-dim*
    { 0 0 } swap [ rect-extent nip vmax ] each-child ;

: init-page-gadgets ( page-canvas -- )
    dup [ parameters>> ] [ clip-displays>> ] bi
    [ <clip-view> <rect-wrapper> ] with map
    add-gadgets drop ;

: <page-canvas> ( clip-displays -- seconds-range gadget )
    page-canvas new swap [ >>clip-displays ] keep
    <range-page-parameters> swapd >>parameters
    dup init-page-gadgets ;

! * Viewer, includes canvas and controls
: <page-viewer> ( clip-displays -- gadget )
    <page-canvas>
    <filled-pile> swap add-gadget
    swap horizontal <slider> fps get recip >>line add-gadget ;

! * Image-control that keeps aspect ratio
TUPLE: clip-timeline-preview < image-control ;
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

! * Editor, includes editable timeline
TUPLE: clip-timeline < timeline clip-displays ;

! ** Clip preview gadgets in the timeline
: <clip-timeline-preview> ( clip-display -- gadget )
    ! clip>> [ clip-image ] <arrow> <image-control> ;
    [ clip>> [ clip-image ] <arrow> clip-timeline-preview new-image-gadget* ]
    [ draw-duration>> [ duration>seconds "%.1fs" sprintf ] <?arrow> <label-control> add-gadget ] bi ;

: <page-timeline> ( clip-displays -- gadget )
    5 10 horizontal <timeline> swap
    [ [ <clip-timeline-preview> ] [ draw-duration>> ] bi timeline-add ] each ;

: <page-editor> ( clip-displays -- gadget )
    vertical <track> swap [ <page-viewer> 0.85 track-add ]
    [ <page-timeline> 0.15 track-add ] bi ;
