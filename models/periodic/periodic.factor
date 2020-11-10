USING: accessors calendar fry kernel literals locals math math.order models
models.arrow models.range sequences timers ;

IN: models.periodic

SLOT: interval
TUPLE: periodic < model
    enable-model
    duration-model
    timer ;

CONSTANT: minimum-interval $[ 10 milliseconds ]

<PRIVATE
: interval-enable? ( duration -- ? )
    dup duration? [ minimum-interval <=> +lt+ = not ] [ drop f ] if ;

! TODO: this should be a hook?
: model-deactivated? ( model -- ? ) ref>> zero? ;

: stop-periodic-timer ( periodic -- )
    timer>> [ stop-timer ] when* ;

: timer-quot ( periodic -- quot )
    '[ _ dup model-deactivated?
      [ stop-timer ]
      [ t swap set-model ] if ] ;

: start-periodic-timer ( periodic duration -- )
    over timer-quot swap every swap timer<< ;

: ensure-model ( obj -- model )
    dup model? [ <model> ] unless ;

PRIVATE>

: update-periodic ( periodic duration -- )
    2dup [ enable-model>> value>> ] [ interval-enable? ] bi* and
    [ start-periodic-timer ]
    [ drop stop-periodic-timer ] if ;

! Sets the interval of a periodic to obj, update.
! GENERIC: set-periodic-interval ( periodic obj -- )
! M: model set-periodic-interval
: set-periodic-interval ( periodic obj -- )
    ensure-model
    over dup duration-model>> [ remove-connection ] [ drop ] if*
    [ add-connection ] [ swap duration-model<< ] [ swap model-changed ] 2tri ;
! M: duration set-periodic-interval <model> set-periodic-interval ;
! M: f set-periodic-interval <model> set-periodic-interval ;

M: periodic interval<< swap set-periodic-interval ;
M: periodic interval>> duration-model>> value>> ;

! This reacts to changes of a model providing the interval
M: periodic model-changed nip dup duration-model>> value>> update-periodic ; inline

M: periodic model-activated dup model-changed ;

! Take a model which must have a value as duration.  If that model changes,
! start a timer according to that interval which sets this model's value to t.
: <periodic> ( duration/model -- model )
    f periodic new-model swap >>interval ;

:: ?inc-model ( ? amount model -- value )
    model value>> amount +
    ? [ dup model set-model ] when ;

! Take a model that holds a number, increment it by amount every duration.  Gets
! activated when the output is activated.  Returns a model that is periodically
! updated with the next value.
:: <counter> ( model amount enable duration -- model )
    duration <periodic>
    [ enable >>value and amount model ?inc-model ] <arrow> ;

! Counts, but stops if the last value was not the same


:: step-range ( amount range -- max? )
    range range-model :> model
    range range-max-value :> max
    model value>> :> value
    value amount 0 or + :> next
    amount [ range move-by ] when*
    next max >= ;

! Take a range model, step the value in periodic increments by step size, stop when done.
! Returns a model used to enable the stepper, and a model which indicates that the maximum range has been reached
:: range-stepper ( range amount interval-duration -- enable range-max )
    f <model> dup
    [ interval-duration and ] <arrow> <periodic>
    [ amount and range step-range ] <arrow> ;
