USING: accessors combinators formatting functors kernel lexer models parser
slots ;

IN: models.model-slots

! Define a slot on class to be model-driven
! Contract:
! - underlying slot must exist
! - Defines slot<<, which sets the model value
! - Defines ?slot<<, which sets the model value conditionally
! - Defines >>?slot along
! - Defines slot>> which reads the model value
! - Defines change-slot, >>slot along
! - Defines slot!>> which possibly forces recomputation
! - Defines slot-model>>, which gets the underlying model

! TODO: conditional changer
! TODO maybe extend to specifying setter
! CLASS: class name
! UNDERLYING: quot: ( obj -- model )
! SLOT: slot name
<FUNCTOR: define-model-slot ( CLASS UNDERLYING SLOT -- )

C IS ${CLASS}
get-S-model DEFINES-PRIVATE get-${SLOT}-model
S<< IS ${SLOT}<<
?S<< IS ?${SLOT}<<
S>> IS ${SLOT}>>
S!>> IS ${SLOT}!>>
S-model>> IS ${SLOT}-model>>

WHERE

: get-S-model ( obj -- model )
    UNDERLYING call( obj -- model ) ; inline

M: C S<< get-S-model set-model ;
M: C ?S<< get-S-model ?set-model ;
M: C S>> get-S-model value>> ;
M: C S!>> get-S-model compute-model ;
M: C S-model>> get-S-model ;

;FUNCTOR>

<PRIVATE
: ensure-protocol-slots ( slot-name -- )
    {
        [ define-protocol-slot ]
        [ "%s-model" sprintf define-reader-generic ]
        [ "%s!" sprintf define-reader-generic ]
        [ "?%s" sprintf [ define-writer-generic ] [ define-setter ] bi ]
    } cleave ;
PRIVATE>

! MODEL-SLOT: class get-underlying model-slot
SYNTAX: MODEL-SLOT:
    scan-word-name scan-object scan-word-name dup ensure-protocol-slots define-model-slot ;
