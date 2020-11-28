USING: accessors arrays combinators.short-circuit controls kernel locals models
models.arrow models.arrow.smart models.product sequences ui.gadgets
ui.gadgets.borders ui.gestures ui.pens.solid ui.theme ;

IN: models.selection
FROM: ui.gadgets.wrappers => wrapper ;

GENERIC: handles-selection? ( gadget -- ? )
GENERIC: handle-selection ( i gadget -- )
M: gadget handles-selection? drop f ;

: find-selection ( gadget -- gadget/f )
    [ handles-selection? ] find-parent ;

GENERIC: selection-index ( gadget -- i )

: notify-selection ( gadget -- )
    dup find-selection
    [
        [ selection-index ]
        [ handle-selection ] bi*
    ] [ drop ] if* ;

! * Selection models
! Sequence of items which are part of the selection
! That sequence can be the dependency of a control, e.g. button
! Model-changed handler responsible for reacting to becoming selected/deselected
! Button can ask model whether it should be considered selected or note
! Button calls toggle-selection-item on the model.  Model decides how to change
! it's value, e.g. depending on whether multi-selection is enabled or not.

! Model is a sequence of items
! TUPLE: selection-control < control multi ;
MIXIN: selection-control
INSTANCE: selection-control control
SLOT: item
SLOT: multi

! Protocol:
GENERIC: selection-changed ( state selection-value -- )
: selected? ( item selection -- state )
    control-value member? ;

M: selection-control on-value-change
    [ item>> ] [ selected? ]
    [ selection-changed ] tri ;

: select-exclusive ( item selection -- )
    [ 1array ] dip ?set-control-value ;

: select-nonexclusive ( item selection -- )
    [ swap suffix ] ?change-control-value ;

: select-item ( item selection -- )
    dup multi>> [ select-nonexclusive ] [ select-exclusive ] if ;

: deselect-item ( item selection -- )
    [ remove ] ?change-control-value ;

: clear-selected ( selection -- )
    f ?set-control-value ;

: toggle-selected ( item selection -- )
    2dup selected? [ deselect-item ] [ select-item ] if ;

! ** Wrapper gadgets that control/display selection status
! Model: sequence of items
<PRIVATE
MEMO: selected-pen ( -- pen ) selection-color <solid> ;
PRIVATE>
TUPLE: selectable-border < border item multi ;
INSTANCE: selectable-border selection-control
M: selectable-border selection-changed
    swap selected-pen f ? >>interior relayout-1 ;

: new-selectable-border ( model item child class -- selectable-border )
    new-border swap >>item
    { 1 1 } >>size
    swap >>model ;

: <selectable-border> ( model item child -- gadget )
    selectable-border new-selectable-border ;

<PRIVATE
: ctrl-left-click? ( gesture -- ? )
    { [ button-down? ] [ mods>> { C+ } sequence= ] } 1&& ;

: selectable-left-click ( gadget -- )
    [ item>> ] keep select-exclusive ;

: selectable-ctrl-left-click ( gadget -- )
    [ item>> ] keep toggle-selected ;

: item-selected? ( gadget -- ? )
    [ item>> ] keep selected? ;
PRIVATE>


! If we are selected, we only handle ctrl-left-click
! FIXME: This is never called? No idea how to conditionally intercept clicks,
! then...
M: selectable-border handles-gesture?
    dup item-selected?
    [ drop ctrl-left-click? ] [ call-next-method ] if ;

! Gesture handling is a bit strange still: We do handle the button-down, while
! any child-button handles the button-up event?
selectable-border H{
    { T{ button-down f f 1 } [ selectable-left-click ] }
    { T{ button-down f { C+ } 1 } [ selectable-ctrl-left-click ] }
    { T{ button-up f { C+ } 1 } [ drop ] }
} set-gestures
