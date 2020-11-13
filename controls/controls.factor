USING: kernel ui.gadgets ui.gadgets.private ;

IN: controls

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
