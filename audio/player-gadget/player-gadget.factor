USING: accessors audio.engine audio.gadget.private calendar combinators
controls.animation kernel locals math math.functions models models.range
namespaces stroke-unit.util ui.gadgets ui.gadgets.borders ;

IN: audio.player-gadget

! CONSTANT: playback-step-ms 10 ;

: audio-playback-range ( audio -- range )
    audio-duration [ 0 0 0 ] dip 0.5 <range> ;

! : audio-playback-stepper ( range -- periodic finished )
!     0.5 dup seconds range-stepper ;
! : audio-playback-stepper ( range -- stepper )
!     0.5 [ seconds ] keep <range-stepper> ;
: audio-playback-animation ( range -- animation )
    0.5 [ seconds ] keep <range-animation> ;

TUPLE: audio-player < border audio audio-clip last-position position animation ;

: remember-position ( player -- ) dup position>> range-value swap last-position<< ;
: position-changed? ( player -- ? ) [ position>> range-value ] [ last-position>> ] bi = not ;

: make-offset-clip ( position-seconds audio -- clip )
    initialize-audio-gadgets
    [ audio-duration / ]
    [ size>> * floor >integer ]
    [ swap audio-slice ] tri
    [ gadget-audio-engine get-global f ] dip f <static-audio-clip> ;

: init-audio-clip ( player -- )
    { [ audio-clip>> [ stop-clip ] when* ]
      [ position>> range-value ]
      [ audio>> make-offset-clip ]
      [ audio-clip<< ] } cleave ;

: resume-audio ( player -- )
    dup position-changed?
    [ dup init-audio-clip ] when
    audio-clip>> play-clip ;

: stop-audio ( player -- )
    [ remember-position ]
    [ audio-clip>> [ pause-clip ] when* ] bi ;

: reset-playback ( player -- )
    position>> 0 swap set-range-value ;

! : maybe-reset-playback ( player -- )
!     dup animation>> finished?
!     [ reset-playback ] [ drop ] if ;

: start-playback ( player -- )
    animation>> start-animation ;
!     {
!         ! [ dup position>> remove-connection ]
!         ! [ paused>> f swap set-model ]
!         [ maybe-reset-playback ]
!         [ resume-audio ]
!         [ animation>> start-animation ] } cleave ;

: stop-playback ( player -- )
    animation>> stop-animation ;
!    { [ audio-clip>> pause-clip ]
!      [ animation>> stop-animation ]
!      [ remember-position ]
!      ! [ paused>> t swap set-model ]
!      ! [ dup position>> add-connection ]
!    } cleave ;

! : toggle-playback ( player -- )
!     dup paused>> value>>
!     [ start-playback ] [ stop-playback ] if ;

GENERIC: on-state-change ( player state -- )
M: running on-state-change drop resume-audio ;
M: object on-state-change drop stop-audio ;

! M: audio-player graft*
!     [ call-next-method ]
!     [ animation>>  ] bi ;

M: audio-player ungraft*
    [ [ audio-clip>> [ stop-clip ] when* ]
      [ animation>> stop-animation ] bi
    ]
    [ call-next-method ] bi ;

! M: audio-player hide-controls gadget-child hide-gadget ;
! M: audio-player show-controls gadget-child show-gadget ;

! : <playback-button> ( player model -- gadget )
!     [ "⯈" "⏸" ? ] <arrow> <label-control> swap '[ drop _ toggle-playback ] <button> ;

! : <playback-slider> ( range -- gadget )
!     horizontal <slider> ;

:: <audio-player> ( audio -- gadget )
    audio audio-playback-range dup audio-playback-animation :> ( range animation )
    animation <animation-controls> audio-player new-border dup :> player
    [ player swap on-state-change ] animation on-change<<
    range >>position
    audio >>audio
    animation >>animation ;
    ! t <model> [ >>paused ] [ player swap <playback-button> ] bi f track-add
    ! range <playback-slider> f track-add ;


! ! Position, state
! TUPLE: playback-model < model range-model  ;

! : <playback-model> ( position-model state-model -- model )
!     2array <product> ;

! : playback-position ( value -- value ) first ; inline
! : playback-state ( value -- value ) second ; inline

! ! * Playback with stepping range model and callbacks
! TUPLE: playback position paused timer finished ;
! GENERIC: on-start ( playback -- )
! GENERIC: on-pause ( playback -- )
! GENERIC: on-reset ( playback -- )
! GENERIC: playback-speed ( playback -- steps/second )
! GENERIC: update-interval ( playback -- seconds )
! GENERIC: total-steps ( playback -- steps )

! : total-duration ( playback -- seconds )
!     [ total-steps ] [ playback-speed ] bi / ;

! : update-step ( playback -- n )
!     [ update-interval ] [ total-duration / ]
!     [ playback-speed ] tri * ;

! : playback-range ( playback -- model )
!     [ 0 0 0 ] dip [ total-steps ] [ update-step ] bi <range> ;

! : range-max? ( range -- ? )
!     [ range-model value>> ] [ range-step value>> + ] [ range-max-value ] tri >= ;

! : finished-model ( range -- model )
!     [ [ first ] [ 4 swap nths + ] [ fourth > ] tri ] <arrow> ;

! ! : update-finished ( playback -- )
! !     [ position>> range-max? ] [ finished>> set-model ] bi ;

! : reset-playback ( playback -- )
!     [ position>> [ range-min-value ] [ set-range-value ] bi ]
!     ! [ update-finished ]
!     [ on-reset ] bi ;

! : playback-finished? ( playback -- ? )
!     finished>> value>> ;

! : maybe-reset ( playback -- )
!     dup playback-finished?
!     [ reset-playback ] [ drop ] if ;

! : start-playback ( playback -- )
!     { [ maybe-reset ]
!       [ paused>> f swap set-model ]
!       [ on-start ]
!       [ timer>> start-timer ] } cleave ;

! : pause-playback ( playback -- )
!     [ timer>> stop-timer ]
!     [ paused>> t swap set-model ]
!     [ on-pause ] tri ;

! :: init-timer ( playback -- )
!     playback update-step :> step
!     playback position>> :> range
!     [ update-step range move-by
!       range range-max?
!       [ pause-playback ] when
!     ]
!     f playback update-interval seconds <timer>
!     playback timer<< ;

! : toggle-playback ( playback -- )
!     dup state>> value>> paused? [ start-playback ] [ pause-playback ] if ;

! : new-playback ( class -- obj )
!     new dup
!     f <model> >>finished
!     t <model> >>paused
!     [ playback-range >>position ]
!     [ init-timer ]
!     [ reset-playback ]
!     tri ;

! : <playback-button> ( playback -- gadget )
!     [ [ "⯈" "⏸" ? ] <arrow> <label-control> ] [ [ toggle-playback ] curry ] <button> ;

! : <playback-slider> ( playback -- gadget )
!     position>> horizontal <slider> ;

! TUPLE: audio-playback < playback audio audio-clip ;
! M: audio-playback on-start
