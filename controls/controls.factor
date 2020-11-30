USING: accessors kernel math.vectors models ui.gadgets ui.gadgets.private
ui.gestures ;

IN: controls

! * Generic abstraction for controls

! Protocol: children can implement on-value-change
! TODO: this might want to be a mixin...
! TUPLE: control < gadget ;
MIXIN: control
GENERIC: on-value-change ( control -- )
M: control on-value-change drop ;
M: control model-changed nip on-value-change ;
: new-control ( model class -- control )
    new swap >>model ;

: notify-control-change ( control -- )
    model>> notify-connections ;

: ?set-control-value ( value control -- )
    model>> ?set-model ;

:: ?change-control-value ( control quot: ( ..a value -- ..b value' ) -- )
    control control-value quot call
    control ?set-control-value ; inline

:: ?change-model-value ( model quot: ( ..a value -- ..b value' ) -- )
    model value>> quot call
    model ?set-model ; inline

! * Drag-controls
! Model is a value intended to be used for relayouting
MIXIN: drag-control
SLOT: last-value
GENERIC: drag-started ( value control -- )
GENERIC: drag-value-changed ( value control -- )
GENERIC: drag-ended ( value control -- )
GENERIC: update-value ( last-value new-value control -- value )
! Relative conversion between mouse deltas and model values
GENERIC: loc>value ( loc control -- value )
M: drag-control drag-started 2drop ; inline
M: drag-control drag-value-changed set-control-value ; inline
M: drag-control drag-ended 2drop ; inline
M: drag-control loc>value drop ; inline
M: drag-control update-value drop v+ ; inline
: begin-drag ( control -- )
    [ control-value ] keep
    [ last-value<< ]
    [ drag-started ] 2bi ;
: do-drag ( control -- )
    [ drag-loc swap loc>value ]
    [ [ last-value>> ] keep update-value ]
    [ drag-value-changed ] tri ;
: end-drag ( control -- )
    [ control-value ] [ drag-ended ] bi ;

CONSTANT: drag-control-gestures
H{
    { T{ button-down f f 1 } [ begin-drag ] }
    { T{ button-up f f 1 } [ end-drag ] }
    { T{ drag } [ do-drag ] }
}

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
