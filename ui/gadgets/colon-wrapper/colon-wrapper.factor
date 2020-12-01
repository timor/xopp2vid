USING: accessors arrays kernel parser sequences strings ui.gadgets
ui.gadgets.borders ui.gadgets.editors ui.gadgets.editors.private
ui.gadgets.tracks ui.gestures vocabs.parser ;

IN: ui.gadgets.colon-wrapper

! * Provides simple colon-based command line for gadget commands

TUPLE: colon-wrapper < track ;
TUPLE: colon-field < action-field ;

M: colon-wrapper focusable-child* gadget-child ;

: execute-command-string-for ( string gadget -- )
    swap ":" drop-prefix drop >string 1array parse-lines curry call( -- ) ;

<PRIVATE
: input-gadget ( gadget -- gadget )
    children>> second ;

: activate-colon-input ( gadget -- )
    input-gadget request-focus ;

: deactivate-colon-input ( gadget -- )
    [ input-gadget editor>> clear-editor ]
    [ gadget-child request-focus ] bi ;

:: make-action-quot ( word gadget target -- quot )
    word vocabulary>> :> vocab
    [| string |
     vocab [ string target execute-command-string-for ] with-current-vocab
     gadget deactivate-colon-input
    ] ;

PRIVATE>

: <colon-field> ( quot -- gadget )
    colon-field [ <editor> ] dip new-border
    dup gadget-child >>editor field-theme swap >>quot ;

: <input-field> ( word gadget target -- gadget )
    make-action-quot <colon-field> ;

! word is used to set the vocab for command evaluation
:: <colon-wrapper> ( word gadget -- gadget )
    vertical colon-wrapper new-track dup :> track
    gadget f track-add
    word track gadget <input-field> f track-add ;

colon-field H{
    { T{ key-down f f "ESC" } [ parent>> deactivate-colon-input ] }
} set-gestures

colon-wrapper H{
    { T{ key-down f f ":" } [ activate-colon-input ] }
} set-gestures
