USING: accessors kernel math models ui.gadgets ui.gadgets.private ui.gestures ;

IN: controls

! * Generic abstraction for controls
! TODO: this might want to be a mixin...
TUPLE: control < gadget ;
GENERIC: on-value-change ( control -- )
M: control on-value-change drop ;
M: control model-changed nip on-value-change ;
: new-control ( model class -- control )
    new swap >>model ;

! * Drag-controls
TUPLE: drag-control < control last-value ;
GENERIC: drag-started ( value control -- )
GENERIC: drag-value-changed ( value control -- )
GENERIC: drag-ended ( value control -- )
GENERIC: loc>value ( loc control -- value )
M: drag-control drag-started 2drop ;
M: drag-control drag-value-changed set-control-value ;
M: drag-control drag-ended 2drop ;
M: drag-control loc>value drop ;
<PRIVATE
: begin-drag ( control -- )
    [ control-value ] keep
    [ last-value<< ]
    [ drag-started ] 2bi ;
: do-drag ( control -- )
    [ drag-loc swap loc>value ]
    [ last-value>> + ]
    [ drag-value-changed ] tri ;
: end-drag ( control -- )
    [ control-value ] [ drag-ended ] bi ;
PRIVATE>

drag-control H{
    { T{ button-down } [ begin-drag ] }
    { T{ button-up } [ end-drag ] }
    { T{ drag } [ do-drag ] }
} set-gestures

! * Control gadget protocol

GENERIC: start-control* ( control -- )
GENERIC: stop-control* ( control -- )

M: object start-control* drop ;
M: object stop-control* drop ;

: start-control ( control -- ) [ start-control* ] [ activate-control ] bi ;
: stop-control ( control -- ) [ stop-control* ] [ deactivate-control ] bi ;


! For gadgets that have controls associated with them
GENERIC: hide-controls* ( gadget -- )
GENERIC: show-controls* ( gadget -- )
M: gadget hide-controls* [ hide-controls* ] each-child ;
M: gadget show-controls* [ show-controls* ] each-child ;

: hide-controls ( gadget -- ) [ hide-controls* ] [ relayout ] bi ;
: show-controls ( gadget -- ) [ show-controls* ] [ relayout ] bi ;
