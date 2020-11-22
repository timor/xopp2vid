USING: accessors arrays calendar colors.constants combinators controls kernel
locals math math.order math.vectors memoize models sequences stroke-unit.util
ui.gadgets ui.gadgets.packs ui.gadgets.packs.private ui.gadgets.private
ui.gadgets.tracks ui.gestures ui.pens.solid ;

IN: ui.gadgets.timeline

! * Gadget for layouting things with durations along an axis


! Model: sequence of durations, or product model?
TUPLE: timeline < track
    timescale                   ! pixel/second
    separation
    ;

TUPLE: separator < drag-control ;
<PRIVATE
MEMO: separator-pen ( -- pen ) COLOR: black 0.15 alpha-color <solid> ;

: find-separation ( gadget -- n )
    [ timeline? ] find-parent [ separation>> ] [ 1 ] if* ;

: square ( x -- dim ) dup 2array ; inline
PRIVATE>
! M: separator layout* separator-pen ;
M: separator loc>value
    [ parent>> orientation>> vdot ]
    [ parent>> timescale>> / ] bi
    ;

separator H{
    { mouse-enter [ separator-pen >>interior parent>> relayout-1 ] }
    { mouse-leave [ f >>interior parent>> relayout-1 ] }
} set-gestures

: <separator> ( model -- gadget ) separator new-control ;

M: separator pref-dim* find-separation square ;
DEFER: wrapper-drag-ended
DEFER: wrapper-drag-started
M: separator drag-ended parent>> wrapper-drag-ended ;
M: separator drag-started parent>> wrapper-drag-started ;

TUPLE: slide-wrapper < pack timescale drag-model ;

:: <slide-wrapper> ( gadget duration timescale orientation -- gadget )
    slide-wrapper new orientation >>orientation 1 >>fill dup :> wrapper
    timescale >>timescale
    duration value>> <model> :> drag-model
    drag-model <separator> :> handle
    drag-model >>drag-model
    duration >>model
    gadget add-gadget
    handle add-gadget ;

<PRIVATE
: slide-wrapper-size ( gadget -- n )
    {
        [ control-value 0 max ]
        [ timescale>> * ]
        [ find-separation + ]
    } cleave ;

: slide-wrapper-pref-dim ( gadget -- dim  )
    [ dim>> ]
    [ slide-wrapper-size square ]
    [ orientation>> ] tri set-axis ;

: swap-models ( gadget -- )
    {
        [ deactivate-control ]
        [ drag-model>> ]
        [ model>> ]
        [ drag-model<< ]
        [ model<< ]
        [ activate-control ]
    } cleave ;

PRIVATE>
M: slide-wrapper pref-dim*
    slide-wrapper-pref-dim ;

! On start, we disconnect from the application model and connect to the drag model
: wrapper-drag-started ( value control -- )
    [ swap-models ] [ set-control-value ] bi ;
    ! [ model>> [ deactivate-model ] ]

! On end, we reconnect to the application model and set it to the last drag value
: wrapper-drag-ended ( value gadget -- )
    [ 0 max ] dip
    [ swap-models ] [ set-control-value ] bi ;
    ! [ duration-model>> set-model ] bi* ;

M: slide-wrapper model-changed ( model gadget -- )
    nip relayout ;
    ! nip [ slide-wrapper-pref-dim ] [ dim<< ]
    ! [ parent>> relayout ] tri ;

M: slide-wrapper focusable-child* ( gadget -- gadget ) gadget-child ;

: drag-handle-dim ( slide-wrapper -- dim )
    [ dim>> ]
    [ find-separation square ]
    [ orientation>> ] tri set-axis ;

: drag-handle-loc ( slide-wrapper -- dim )
    [ slide-wrapper-size ]
    [ find-separation - square { 0 0 } swap ]
    [ orientation>> ] tri set-axis ;

: layout-drag-handle ( slide-wrapper -- )
    [ children>> second ]
    [ drag-handle-dim >>dim ]
    [ drag-handle-loc >>loc ] tri drop ;

M: slide-wrapper layout*
    [ pref-dim ]
    [ gadget-child dim<< ]
    [ layout-drag-handle ] tri ;
    ! dup slide-wrapper-sizes pack-layout ;

: new-timeline ( separation timescale orientation class -- gadget )
    new-track swap >>timescale swap >>separation ;

: <timeline> ( separation timescale orientation -- gadget )
    timeline new-timeline ;

:: timeline-add ( timeline gadget duration -- timeline )
    gadget duration timeline [ timescale>> ] [ orientation>> ] bi <slide-wrapper> :> wrapper
    timeline wrapper f track-add ;

: set-timescale ( timescale timeline -- )
    swap
    [ >>timescale drop ]
    [ swap children>> [ timescale<< ] with each ]
    [ drop children>> [ relayout ] each ] 2tri ;
