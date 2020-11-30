USING: accessors arrays colors.constants combinators controls kernel math
math.order math.vectors models sequences stroke-unit.util ui.gadgets
ui.gadgets.border-handles ui.gadgets.private ui.gadgets.tracks ui.gestures
ui.pens.solid ;

IN: ui.gadgets.timeline

! * Gadget for layouting things with durations along an axis


! Model: sequence of durations, or product model?
TUPLE: timeline < track
    timescale                   ! pixel/second
    handle-width
    ;

TUPLE: drag-handle < gadget last-value ;
INSTANCE: drag-handle drag-control
<PRIVATE
MEMO: drag-handle-pen ( -- pen ) COLOR: black 0.15 alpha-color <solid> ;

: find-handle-width ( gadget -- n )
    [ timeline? ] find-parent [ handle-width>> ] [ 1 ] if* ;

: square ( x -- dim ) dup 2array ; inline
PRIVATE>
DEFER: find-slide-wrapper
M: drag-handle update-value drop + ; inline
M: drag-handle loc>value
    find-slide-wrapper
    [ orientation>> vdot ]
    [ timescale>> / ] bi ;

: <drag-handle> ( model -- gadget ) drag-handle new-control ;

DEFER: wrapper-drag-ended
DEFER: wrapper-drag-started
M: drag-handle drag-ended parent>> wrapper-drag-ended ;
M: drag-handle drag-started parent>> wrapper-drag-started ;

drag-handle drag-control-gestures set-gestures

TUPLE: slide-wrapper < border-handle timescale drag-model ;
: find-slide-wrapper ( gadget -- gadget/f )
    [ slide-wrapper? ] find-parent ;

:: <slide-wrapper> ( gadget duration timescale orientation -- gadget )
    duration value>> <model> :> drag-model
    drag-model <drag-handle> drag-handle-pen >>interior :> handle
    gadget handle +east+ slide-wrapper new-border-handle
    orientation >>orientation
    timescale >>timescale
    drag-model >>drag-model
    duration >>model ;

<PRIVATE
: slide-wrapper-size ( gadget -- n )
    {
        [ control-value 0 max ]
        [ timescale>> * ]
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

! On end, we reconnect to the application model and set it to the last drag value
: wrapper-drag-ended ( value gadget -- )
    [ 0 max ] dip
    [ swap-models ] [ set-control-value ] bi ;

M: slide-wrapper model-changed ( model gadget -- )
    nip relayout ;

M: slide-wrapper focusable-child* ( gadget -- gadget ) gadget-child ;

: new-timeline ( handle-width timescale orientation class -- gadget )
    new-track swap >>timescale swap >>handle-width ;

: <timeline> ( handle-width timescale orientation -- gadget )
    timeline new-timeline ;

:: timeline-add ( timeline gadget duration -- timeline )
    gadget duration timeline [ timescale>> ] [ orientation>> ] bi <slide-wrapper> :> wrapper
    timeline handle-width>> wrapper width<<
    timeline wrapper f track-add ;

: set-timescale ( timescale timeline -- )
    swap
    [ >>timescale drop ]
    [ swap children>> [ timescale<< ] with each ]
    [ drop children>> [ relayout ] each ] 2tri ;
