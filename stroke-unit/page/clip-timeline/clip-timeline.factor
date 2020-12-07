USING: accessors arrays audio audio.player-gadget calendar colors.constants
combinators continuations formatting images images.viewer images.viewer.private
io.pathnames kernel math math.order math.rectangles models models.arrow
models.arrow.smart models.async models.selection opengl.textures sequences
stroke-unit.clip-renderer stroke-unit.clips stroke-unit.util timers ui.gadgets
ui.gadgets.labels ui.gadgets.model-children ui.gadgets.scrollers
ui.gadgets.timeline ui.gadgets.wrappers.rect-wrappers ui.gestures ui.pens.solid
ui.render ;

IN: stroke-unit.page.clip-timeline

! * Image-control that keeps aspect ratio and displays other stuff for use in timeline
TUPLE: clip-timeline-preview < image-control clip-display current-time-model ;

M: clip-timeline-preview draw-gadget*
    dup ?update-texture
    dup image>>
    [ [ [ image-gadget-texture ] [ dim>> ] bi ]
      [ images:image-dim adjust-image-dim ] bi*
      swap draw-scaled-texture ]
    [ drop ] if* ;

: <preview-position--> ( current-time clip-display -- model )
    [ start-time-model>> ] [ draw-duration-model>> ] bi
    [ 0.01 max [ - ] dip /
      dup 0 1 between? [ drop f ] unless
    ] <?smart-arrow> ;

:: audio-clip-schedule ( current-time start-time clip -- offset delay )
    start-time clip load-audio audio-duration + :> end-time
    current-time end-time >=
    [ f f ]
    [ current-time start-time - [ 0 max ] [ neg 0 max seconds ] bi ] if ;

: compute-audio-clip ( current-time start-time clip -- delay/f clip/f )
    [ audio-clip-schedule ] keep over
    [| offset delay clip |
     delay
     offset clip load-audio make-offset-clip ]
    [ 3drop f f ] if ;

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

MEMO: <empty-image> ( -- image )
    <image> { 0 0 } >>dim
    L >>component-order
    ubyte-components >>component-type
    B{ } >>bitmap ;
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

: limit-string ( str n -- str )
    2dup swap length <
    [ 1 - tail-slice* "…" prepend ] [ drop ] if ;

: clip-audio-label ( clip -- str )
    dup audio-path>> dup +no-audio+?
    [ 2drop "" ]
    [ [ clip-audio-duration ] [ file-stem 8 limit-string ] bi* "%.1fs %s" sprintf ] if ;

: <audio-label--> ( clip-display -- str-model )
    clip-model>> [ clip-audio-label ] <arrow> ;

: <clip-parameter-string--> ( clip-display -- str )
    {
        [ start-time-model>> ]
        [ draw-duration-model>> ]
        [ stroke-speed-model>> ]
        [ <audio-label--> ]
    } cleave
    [ [ ] 2dip

      ! dup audio-path>> +no-audio+?
      ! [ drop "" ] [ clip-audio-duration "%.1fs" sprintf ] if
      ! "%.1fs\n+%.1fs\n%.1fpt/s\n\n\n%-30s"
      "%.1fs\n+%.1fs\n%.1fpt/s\n\n\n%s"
      sprintf ] <?smart-arrow> ;

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
        [ pick current-time>>
          [ swap <preview-cursor> add-gadget ]
          [ >>current-time-model ] bi ]
        [ swapd [ timescale>> ] dip
          <audio-indicator> add-gadget
          ! 2drop
        ]
    } cleave ;

: clip-preview>time ( gadget -- time )
    [ hand-click-rel first ]
    [ dim>> first / ]
    [ clip-display>> [ draw-duration>> * ] [ start-time!>> + ] bi ] tri ;

: preview-click ( gadget -- )
    [ clip-preview>time ]
    [ current-time-model>> ?set-model ] bi ;

clip-timeline-preview H{
    { T{ button-down f { C+ } 1 } [ preview-click ] }
} set-gestures

! ** Clip Preview Timeline

! Model: sequence of clip-displays
TUPLE: clip-timeline < timeline parameters ;
INSTANCE: clip-timeline model-children

<PRIVATE
! HACK: gadget empty when called, better: inhibit reaction to scrolling when parent is being rebuilt
: scroll-bounds ( gadget --  )
    [ [ dim>> { 0 0 } swap <rect> ] keep scroll>rect ] curry 0.1 seconds later drop ;
PRIVATE>
TUPLE: scroll-to-select-border < selectable-border ;
M: scroll-to-select-border selection-changed
    [ call-next-method ] 2keep
    swap [ scroll-bounds ] [ drop ] if ;
: <scroll-to-select-border> ( model item child -- gadget )
    scroll-to-select-border new-selectable-border ;

M:: clip-timeline child-model>gadget ( model gadget -- gadget )
    gadget parameters>> model <clip-timeline-preview>
    [ gadget find-selection model ] dip <scroll-to-select-border> { 1 1 } >>fill ;

M: clip-timeline add-model-children
    swap [ dup gadget-child clip-display>> draw-duration-model>> timeline-add ] each ;

:: <page-timeline> ( page-parameters clip-displays -- gadget )
    10 10 horizontal clip-timeline new-timeline
    clip-displays >>model
    page-parameters >>parameters ;

M: clip-timeline focusable-child* drop t ;
