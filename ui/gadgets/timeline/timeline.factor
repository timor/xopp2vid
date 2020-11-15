USING: accessors arrays calendar colors.constants combinators controls kernel
locals math math.order math.vectors models sequences ui.gadgets ui.gadgets.packs
ui.gadgets.packs.private ui.gadgets.tracks ui.pens.solid ;

IN: ui.gadgets.timeline

! * Gadget for layouting things with durations along an axis


! Model: sequence of durations, or product model?
TUPLE: timeline < track
    timescale                   ! pixel/second
    separation
    ;

TUPLE: separator < drag-control ;
M: separator layout* COLOR: black <solid> >>interior drop ;
<PRIVATE
: find-separation ( gadget -- n )
    [ timeline? ] find-parent separation>> ;
PRIVATE>
M: separator loc>value
    [ parent>> orientation>> vdot ]
    [ parent>> timescale>> / ] bi
    ;

: <separator> ( model -- gadget ) separator new-control ;

M: separator pref-dim* find-separation dup 2array ;
DEFER: wrapper-drag-ended
M: separator drag-ended parent>> wrapper-drag-ended ;

TUPLE: slide-wrapper < pack timescale duration-model ;

:: <slide-wrapper> ( gadget duration timescale orientation -- gadget )
    slide-wrapper new orientation >>orientation 1 >>fill dup :> wrapper
    timescale >>timescale
    duration value>> duration>seconds <model> :> drag-model
    drag-model <separator> :> handle
    drag-model >>model
    duration >>duration-model
    gadget add-gadget
    handle add-gadget ;

M: slide-wrapper model-changed ( model gadget -- ) nip relayout ;

<PRIVATE
: wrapper-offset ( wrapper -- n )
    parent>> separation>> 2 * ;

: slide-wrapper-sizes ( gadget -- seq )
    {
        [ control-value 0 max ]
        [ timescale>> * ]
        [ wrapper-offset + ]
        [ find-separation ]
    } cleave
    [ dup 2array ] bi@ 2array ;
PRIVATE>

! TODO: Make pack-sizes generic
M: slide-wrapper layout* dup slide-wrapper-sizes pack-layout ;
M: slide-wrapper pref-dim* dup slide-wrapper-sizes pack-pref-dim ;

: wrapper-drag-ended ( value gadget -- )
    [ 0 max seconds ] [ duration-model>> set-model ] bi* ;

: <timeline> ( separation timescale orientation -- gadget )
    timeline new-track swap >>timescale swap >>separation ;

:: timeline-add ( timeline gadget duration -- timeline )
    gadget duration timeline [ timescale>> ] [ orientation>> ] bi <slide-wrapper> :> wrapper
    timeline wrapper f track-add ;

: set-timescale ( timeline timescale -- )
    [ >>timescale drop ]
    [ swap children>> [ timescale<< ] with each ]
    [ drop children>> [ relayout ] each ] 2tri ;
