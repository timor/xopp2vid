USING: accessors kernel locals math models models.range timers ;

IN: animators

! * Timer running until quot returns f
:: <timed-loop> ( quot interval-duration -- timer )
    [ ] f interval-duration <timer> dup :> timer
    [ quot call [ timer stop-timer ] unless ] >>quot ;


! * Animating a range model
TUPLE: range-animator interval-duration step range timer paused ;

: set-paused ( obj ? -- ) swap paused>> set-model ;

: paused? ( obj -- ? ) paused>> value>> ;

: reset-range ( obj -- )
    range>> [ range-min-value ] [ set-range-value ] bi ;

: pause-animation ( obj -- )
    dup t set-paused
    timer>> stop-timer ;

: maybe-reset ( obj -- )
    dup
    [ range>> range-value ]
    [ step>> + ]
    [ range>> range-max-value ] tri
    >= [ reset-range ] [ drop ] if ;

: start-animation ( obj -- )
    dup maybe-reset
    dup f set-paused
    timer>> start-timer ;

: stop-animation ( obj -- )
    [ pause-animation ]
    [ reset-range ] bi ;

:: range-animator-timer ( obj -- timer )
    obj [ interval-duration>> ] [ step>> ] [ range>> ] tri :> ( interval-duration step range )
    ! range range-min-value :> start
    range range-value :> last-value!
    [
        ! started
        ! [
            step range move-by
            range range-value
            [ last-value = [ obj pause-animation ] when ]
            [ last-value! ] bi
            obj paused? not
        ! ]
        ! [ start range set-range-value t started! t ] if
    ] interval-duration <timed-loop> ;

<PRIVATE
: init-range-timer ( obj -- )
    dup range-animator-timer >>timer drop ;

PRIVATE>
: <range-animator> ( interval-duration step range -- obj )
    f t <model> range-animator boa dup init-range-timer ;

: restart-animation ( obj -- )
    [ stop-animation ]
    [ start-animation ] bi ;

: toggle-animation ( obj -- )
    dup paused? [ start-animation ] [ pause-animation ] if ;
