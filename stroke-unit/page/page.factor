USING: accessors arrays assocs calendar colors.constants combinators formatting
grouping hashtables.identity images.viewer images.viewer.private kernel locals
math math.order math.rectangles math.vectors memoize models models.arrow
models.arrow.smart models.range namespaces opengl.textures sequences sets
stroke-unit.clip-renderer stroke-unit.clips stroke-unit.models.clip-display
stroke-unit.util ui.gadgets ui.gadgets.labels ui.gadgets.packs
ui.gadgets.private ui.gadgets.scrollers ui.gadgets.sliders ui.gadgets.timeline
ui.gadgets.tracks ui.gadgets.wrappers.rect-wrappers ui.gestures ui.images
ui.pens.solid ui.render vectors ;

IN: stroke-unit.page
FROM: namespaces => set ;

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
: (clip-position) ( time start-time duration -- position )
    duration>seconds [ - ] dip / 0 1 clamp ;

: <clip-position--> ( time-model start-time-model duration-model -- position-model )
    [ (clip-position) ] <?smart-arrow> ;

: <frame-select--> ( image-seq-model time-model start-time-model duration-model -- element-model )
    <clip-position--> [ swap float-nth ] <smart-arrow> ;

! All slots models
TUPLE: page-parameters current-time draw-scale timescale ;
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
    [ <clip-display> ] curry map >vector
    dup 2 <clumps> [ first2 connect-clip-displays ] each ;

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
    over [ clear-gadget ] [ parameters>> ] bi
    swap [ find-clip-view ] with map add-gadgets drop ;

M: page-canvas model-changed
    swap value>> [ synchronize-views ] keepd relayout ;

! : init-page-gadgets ( page-canvas -- )
!     dup [ parameters>> ] [ clip-displays>> ] bi
!     [ <clip-view> <rect-wrapper> ] with map
!     add-gadgets drop ;

: <page-canvas> ( page-parameters clip-displays -- gadget )
    page-canvas new swap >>model
    swap >>parameters ;
    ! dup init-page-gadgets ;

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

SYMBOL: focused-clip-index
MEMO: preview-pen ( -- pen )
    COLOR: red <solid> ;

DEFER: set-focus-index
: preview-gain-focus ( gadget -- )
    [ preview-pen >>boundary relayout-1 ]
    [ dup clip-display>> set-focus-index ] bi ;

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

! ** Clip Preview Timeline

! Model: sequence of clip-displays
TUPLE: clip-timeline < timeline ;

: focus-clip-index ( timeline i -- )
    swap children>> ?nth [ request-focus ] when* ;

: when-focus ( quot: ( index -- ) -- )
    focused-clip-index get 0 or swap call ; inline

: timeline-focus-left ( timeline -- ) [ swap 1 - focus-clip-index ] curry when-focus ;

: timeline-focus-right ( timeline -- ) [ swap 1 + focus-clip-index ] curry when-focus ;

SYMBOL: clip-preview-cache
clip-preview-cache [ IH{ } clone ] initialize

:: find-timeline-preview ( page-parameters clip-display -- gadget )
    clip-display clip-preview-cache get
    [ [ page-parameters current-time>> ] dip <clip-timeline-preview> ] cache ;

! : changed-clip-displays ( new-clip-displays children -- added removed )
!     [ clip-display>> ] map
!     [ diff members ]
!     [ swap diff members ] 2bi ;

! : add-gadgets-lazy ( parent childen -- parent )
!     not-in-layout over [ (add-gadget) ] curry each ;

! :: synchronize-previews ( gadget clip-displays -- )
!     clip-displays gadget children>> changed-clip-displays :> ( added removed )
!     gadget children>> [ dup removed member? [ unparent ] [ drop ] if ] each
!     gadget parent>> page-parameters>> added [ find-clip-view ] with map
!     gadget swap add-gadgets-lazy
!     ! This is the dangerous part: we assume that all children are now grafted
!     ! and set-equivalent to the clip-displays.
!     clip-view-cache get clip-displays [ swap at ] with map >vector >>children drop ;
DEFER: find-page-parameters
: synchronize-previews ( gadget clip-displays -- )
    over [ clear-gadget ] [ find-page-parameters ] bi
    swap [ [ find-timeline-preview ] [ draw-duration>> ] bi timeline-add ] with each drop ;

M: clip-timeline model-changed
    swap value>> [ synchronize-previews ] keepd relayout ;

clip-timeline H{
    { T{ key-down f f "h" } [ timeline-focus-left ] }
    { T{ key-down f f "l" } [ timeline-focus-right ] }
} set-gestures

:: <page-timeline> ( clip-displays -- gadget )
    5 10 horizontal clip-timeline new-timeline
    clip-displays >>model ;

! clip-displays is a model
TUPLE: page-editor < track page-parameters clip-displays timescale-observer ;

:: <page-editor> ( clip-displays -- gadget )
    vertical page-editor new-track
    clip-displays <range-page-parameters> :> ( range-model page-parameters )
    clip-displays <model> [ >>clip-displays ] keep
    [ page-parameters swap <page-canvas> 0.85 track-add ]
    [ <page-timeline> <scroller> 0.15 track-add ] bi
    range-model <page-slider> f track-add
    page-parameters >>page-parameters ;

: canvas-gadget ( editor -- gadget ) children>> first ;
: timeline-gadget ( editor -- gadget ) children>> second viewport>> gadget-child ;

M: page-editor graft*
    { [ call-next-method ]
      [ page-parameters>> timescale>> [ [ set-timescale ] keepd ] ]
      [ timeline-gadget swap curry <arrow> [ activate-model ] keep ]
      [ timescale-observer<< ] } cleave ;

M: page-editor ungraft*
    [ timescale-observer>> deactivate-model ]
    [ call-next-method ] bi ;

M: page-editor focusable-child* timeline-gadget ;

: find-page-parameters ( gadget -- paramters )
    [ page-editor? ] find-parent dup [ page-parameters>> ] when ;

: set-focus-index ( gadget clip-display -- )
    swap [ page-editor? ] find-parent
    [ clip-displays>> compute-model index focused-clip-index set ]
    [ drop ] if* ;

: clamp-index ( seq i -- i )
    swap length 1 - 0 swap clamp ;

: editor-refocus ( editor -- )
    dup clip-displays>> compute-model focused-clip-index get clamp-index
    [ timeline-gadget ] dip focus-clip-index ;

! ** Manipulating the clip-display model value
SYMBOL: kill-stack
kill-stack [ V{ } clone ] initialize

! Following things need to be done:
! 1. Connect the predecessor and the successor
! 2. Deactivate the model-model
! 2. Remove the clip from the clip-displays list
! 3. Remove the gadget from the canvas
! 4. Remove the gadget from the timeline

: this/next ( seq index -- elt elt/f )
    [ swap nth ] [ 1 + swap ?nth ] 2bi ;

: this/prev ( seq index -- elt elt/f )
    [ swap nth ] [ 1 - swap ?nth ] 2bi ;

: connect-neighbours ( clip-displays index -- )
    this/next
    [ [ prev>> [ compute-model ] [ ! deactivate-model-model
            drop
                                 ] bi ] dip
      connect-clip-displays  ]
    [ drop ] if* ;

: kill-nth-clip-display ( clip-displays index -- seq )
    swap [ nth kill-stack get push ] [ remove-nth ] 2bi ;

: delete-nth-clip-display ( clip-displays index -- seq display )
    kill-nth-clip-display kill-stack get pop ;

! before manipulating the sequence
: connect-insert-before ( clip-displays index clip-display -- )
    [ swap nth dup prev>> compute-model ] dip
    [ connect-clip-displays ]
    [ swap connect-clip-displays ] bi ;

: insert-clip-before ( clip-displays index clip-display -- seq )
    3dup connect-insert-before
    spin insert-nth ;

: connect-insert-after ( clip-displays index clip-display -- )
    [ [ swap nth ] dip connect-clip-displays ]
    [ -rot 1 + swap ?nth [ connect-clip-displays ] [ drop ] if* ] 3bi ;

: insert-clip-after ( clip-displays index clip-display -- seq )
    3dup connect-insert-after
    [ 1 + ] dip spin insert-nth ;

: <split-clip-display> ( clip-display position -- obj1 obj2 )
    [ [ clip>> compute-model ] dip clip-split-at ]
    [ drop stroke-speed>> compute-model ] 2bi
    [ <clip-display> ] curry bi@ ;

! : split-nth-clip-at ( clip-displays index position -- seq )
!     2over delete-nth-clip-display nip
!     swap <split-clip-display>
!     [ insert-clip-before ] bi-curry@ bi ;
! : split-nth-clip-at ( clip-displays index position -- seq )
!     [ delete-nth-clip-display ] dip ;

! ** Doing that in editor context

! TODO: use combinator
: editor-kill-clip ( gadget index -- )
    over clip-displays>> compute-model
    2dup swap connect-neighbours
    swap kill-nth-clip-display swap clip-displays>> set-model ;

:: change-clip-displays ( gadget quot: ( ... value -- ... new-value/f ) -- gadget )
    gadget clip-displays>> dup :> model compute-model
    quot call [ model set-model ] when* gadget ; inline

: change-clip-displays-focused ( gadget quot: ( ...value index -- ... new-value ) -- gadget )
    [ focused-clip-index get ] dip curry change-clip-displays ; inline

:: editor-yank-before ( gadget -- )
    kill-stack get
    [
        pop :> to-insert
        gadget [
            to-insert insert-clip-before
        ] change-clip-displays-focused drop
    ] unless-empty ;

:: editor-yank-after ( gadget -- )
    kill-stack get
    [
        pop :> to-insert
        gadget [
            to-insert insert-clip-after
        ] change-clip-displays-focused drop
    ] unless-empty ;
    ! [ 2drop ]
    ! [| stack index diplays gadget index |
    !  stack pop :> to-insert
    !  gadget clip-displays>> dup :> model compute-model :> displays
    !  displays index to-insert
    !  insert-clip-before
    !  ! connect-insert-before
    !  ! to-insert index displays insert-nth
    !  model set-model
    ! ] if-empty ;

: editor-kill-focused ( gadget -- )
    [ focused-clip-index get editor-kill-clip ]
    [ editor-refocus ] bi ;

: <merged-clip-display> ( d1 d2 -- d )
    [ [ clip>> compute-model ] bi@ clip-merge ] keepd
    stroke-speed>> value>> [ stroke-speed get ] unless* <clip-display> ;

: editor-merge-left ( gadget -- )
    [| seq i |
     i 1 - seq nth [
         seq i delete-nth-clip-display :> this
         i 1 - delete-nth-clip-display :> prev
         ! i dup 1 - [ delete-nth-clip-display ] bi-curry@ bi
         ! swap
         i 2 - prev this <merged-clip-display> insert-clip-after
         ! i 1 - delete-nth-clip-display
         ! i 2 - prev this <merged-clip-display> insert-clip-after
     ] [ f ] if
    ] change-clip-displays-focused editor-refocus ;

! : editor-yank-before ( gadget -- ) focused-clip-index get editor-insert-clip-before ;
! : editor-yank-after ( gadget -- ) focused-clip-index get editor-insert-clip-after ;

: editor-move ( gadget offset -- )
    [ drop ]
    [ [ timeline-gadget ] dip focused-clip-index get + focus-clip-index ]
    if-zero ;

: editor-change-timescale ( gadget factor -- )
    over page-parameters>> timescale>> compute-model *
    swap page-parameters>> timescale>> set-model ;

: nth-clip-display-position ( gadget clip-displays n -- position )
    [ page-parameters>> current-time>> compute-model ] 2dip swap nth
    [ start-time>> ] [ draw-duration>> ] bi [ compute-model ] bi@
    (clip-position) ;

: editor-focused-clip-position ( gadget -- position )
    dup clip-displays>> compute-model focused-clip-index get
    nth-clip-display-position ;

: editor-split-focused-clip ( gadget -- )
    {
        [ editor-focused-clip-position ]
        [ editor-kill-focused
          kill-stack get pop swap <split-clip-display> [ kill-stack get push ] bi@ ]
        [ -1 editor-move ]
        [ editor-yank-before ]
        [ editor-yank-before ]
    } cleave ;
    ! dup editor-kill-clip
    ! kill-stack get pop <split-clip-display>
    ! [  ]
    ! [ split-nth-clip-at ] curry change-clip-displays-focused drop ;

page-editor H{
    { T{ key-down f f "x" } [ editor-kill-focused ] }
    { T{ key-down f f "P" } [ editor-yank-before ] }
    { T{ key-down f f "p" } [ editor-yank-after ] }
    { T{ key-down f f "m" } [ editor-merge-left ] }
    { T{ key-down f f "s" } [ editor-split-focused-clip ] }
    { T{ key-down f f "-" } [ 1/2 editor-change-timescale ] }
    { T{ key-down f f "=" } [ 2 editor-change-timescale ] }
} set-gestures
