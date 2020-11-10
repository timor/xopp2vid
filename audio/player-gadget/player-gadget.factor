USING: accessors calendar combinators kernel locals math models models.arrow
models.range sequences timers ;

IN: audio.player-gadget

! CONSTANT: playback-step-ms 10 ;

! Position, state
TUPLE: playback-model < product animator ;

: <playback-model> ( position-model state-model -- model )
    2array <product> ;

: playback-position ( value -- value ) first ; inline
: playback-state ( value -- value ) second ; inline

! * Playback with stepping range model and callbacks
TUPLE: playback position paused timer finished ;
GENERIC: on-start ( playback -- )
GENERIC: on-pause ( playback -- )
GENERIC: on-reset ( playback -- )
GENERIC: playback-speed ( playback -- steps/second )
GENERIC: update-interval ( playback -- seconds )
GENERIC: total-steps ( playback -- steps )

: total-duration ( playback -- seconds )
    [ total-steps ] [ playback-speed ] bi / ;

: update-step ( playback -- n )
    [ update-interval ] [ total-duration / ]
    [ playback-speed ] tri * ;

: playback-range ( playback -- model )
    [ 0 0 0 ] dip [ total-steps ] [ update-step ] bi <range> ;

: range-max? ( range -- ? )
    [ range-model value>> ] [ range-step value>> + ] [ range-max-value ] tri >= ;

: finished-model ( range -- model )
    [ [ first ] [ 4 swap nths + ] [ fourth > ] tri ] <arrow> ;

! : update-finished ( playback -- )
!     [ position>> range-max? ] [ finished>> set-model ] bi ;

: reset-playback ( playback -- )
    [ position>> [ range-min-value ] [ set-range-value ] bi ]
    ! [ update-finished ]
    [ on-reset ] bi ;

: playback-finished? ( playback -- ? )
    finished>> value>> ;

: maybe-reset ( playback -- )
    dup playback-finished?
    [ reset-playback ] [ drop ] if ;

: start-playback ( playback -- )
    { [ maybe-reset ]
      [ paused>> f swap set-model ]
      [ on-start ]
      [ timer>> start-timer ] } cleave ;

: pause-playback ( playback -- )
    [ timer>> stop-timer ]
    [ paused>> t swap set-model ]
    [ on-pause ] tri ;

:: init-timer ( playback -- )
    playback update-step :> step
    playback position>> :> range
    [ update-step range move-by
      range range-max?
      [ pause-playback ] when
    ]
    f playback update-interval seconds <timer>
    playback timer<< ;

: toggle-playback ( playback -- )
    dup state>> value>> paused? [ start-playback ] [ pause-playback ] if ;

: new-playback ( class -- obj )
    new dup
    f <model> >>finished
    t <model> >>paused
    [ playback-range >>position ]
    [ init-timer ]
    [ reset-playback ]
    tri ;

: <playback-button> ( playback -- gadget )
    [ [ "⯈" "⏸" ? ] <arrow> <label-control> ] [ [ toggle-playback ] curry ] <button> ;

: <playback-slider> ( playback -- gadget )
    position>> horizontal <slider> ;

TUPLE: audio-playback < playback audio audio-clip ;
M: audio-playback on-start
