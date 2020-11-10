USING: functors ;

IN: models.model-slots

! Define a slot on class to be model-driven
! Contract:
! - class must be an obsecver
! - underlying slot must exist
! - must implement model-changed word
! - model-changed is called for any model slot on class

<PRIVATE

: ensure-model ( obj -- model ) dup model? [ <model> ] unless ;

PRIVATE>

<FUNCTOR: define-model-slot ( C U S -- )

C IS ${C}
set-S DEFINES set-${S}
S>> IS ${S}>>
S<< IS ${S}<<
U>> IS ${U}>>
U<< IS ${U}<<

WHERE

: set-S ( obj value/model -- )
    ensure-model
    over dup U>> [ remove-connection ] [ drop ] if*
    [ add-connection ] [ swap U<< ] [ swap model-changed ] 2tri ;

M: C S<< over model? [ swap set-S ] [
        dup U>> dup model? [ nip set-model ] [ drop swap set-S ] if ] if ;
M: C S>> U>> dup [ value>> ] when ;

;FUNCTOR>

! MODEL-SLOT: class underlying-slot model-slot
SYNTAX: MODEL-SLOT:
    scan-token scan-token scan-token dup define-protocol-slot define-model-slot ;
