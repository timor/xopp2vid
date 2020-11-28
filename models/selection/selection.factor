USING: accessors arrays kernel models models.model-slots models.product
sequences ui.gadgets ui.gadgets.borders ui.gestures ui.pens.solid ui.theme ;

IN: models.selection

! * Selection Models
TUPLE: selection < models.product:product multi? ;
MODEL-SLOT: selection [ dependencies>> first ] items
MODEL-SLOT: selection [ dependencies>> second ] selected

: <selection> ( items-model -- obj )
    f <model> 2array selection new-product ;

! * Selection Model manipulation
: selected? ( item selection -- state )
    selected>> member? ;

: select-exclusive ( item selection -- )
    [ 1array ] dip ?selected<< ;

: select-nonexclusive ( item selection -- )
    [ swap suffix ] change-selected drop ;

: select-item ( item selection -- )
    dup multi?>> [ select-nonexclusive ] [ select-exclusive ] if ;

: deselect-item ( item selection -- )
    [ remove ] change-selected drop ;

: clear-selected ( selection -- )
    f swap ?selected<< ;

: select-all ( selection -- )
    [ items>> ] [ ?selected<< ] bi ;

: toggle-selected ( item selection -- )
    2dup selected? [ deselect-item ] [ select-item ] if ;

! * Protocol for things that have selection models

MIXIN: has-selection
SLOT: selection

! * Getting selection model from current Gadget
: find-selection ( gadget -- selection/f )
    [ has-selection? ] find-parent
    dup [ selection>> ] when ;

! * Things that can be selected
MIXIN: selection-control
! INSTANCE: selection-control control
SLOT: item

! ** Control selection from current gadget

: notify-select-click ( gadget -- )
    [ item>> ] [ find-selection ] bi
    [ select-exclusive ] [ drop ] if* ;

: notify-select-ctrl-click ( gadget -- )
    [ item>> ] [ find-selection ] bi
    [ toggle-selected ] [ drop ] if* ;

! ** React to selection changes

GENERIC: selection-changed ( state selection-control -- )

M: selection-control model-changed
    [ item>> swap selected? ]
    [ selection-changed ] bi ;

! * Wrapper gadgets that control/display selection status
! Model: sequence of items
<PRIVATE
MEMO: selected-pen ( -- pen ) selection-color <solid> ;
PRIVATE>
TUPLE: selectable-border < border item ;
INSTANCE: selectable-border selection-control
M: selectable-border selection-changed
    swap selected-pen f ? >>interior relayout-1 ;

: new-selectable-border ( model item child class -- selectable-border )
    new-border swap >>item
    swap >>model ;

: <selectable-border> ( model item child -- gadget )
    selectable-border new-selectable-border ;

! Gesture handling is a bit strange still: We do handle the button-down, while
! any child-button handles the button-up event?
selectable-border H{
    { T{ button-down f f 1 } [ notify-select-click ] }
    { T{ button-down f { C+ } 1 } [ notify-select-ctrl-click ] }
    { T{ button-up f { C+ } 1 } [ drop ] }
} set-gestures
