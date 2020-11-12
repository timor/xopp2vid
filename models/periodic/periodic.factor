USING: accessors calendar combinators fry kernel literals locals math math.order
models models.arrow models.delay models.model-slots models.range sequences
timers ;

IN: models.periodic

! ! Return a quotation which returns the last value along with the one it was
! ! called before that, starting with f
! :: <diff> ( quot: ( x -- x+1 ) -- quot: ( x -- x+1 x ) )
!     f :> last!
!     [ quot call last over last! ] ;

! Enable with activate-control


! Two conditions must be satisfied for this to run:
! 1. The stepper must be activated ( e.g. by connecting to  )
! 2. The stepper must be enabled
! :: <range-stepper> ( range amount duration -- model )
!     f range-stepper new-model :> stepper
!     [ amount + ] <diff> :> closure
!     range duration <delay> [
!         first closure call :> ( next prev )
!         next prev = dup [ next range set-range-value ] unless
!     ]

!     swap >>quot [ add-dependency ] keep ;


SLOT: interval
TUPLE: periodic < model
    enable-model
    duration-model
    timer ;
MODEL-SLOT: periodic enable-model enabled
MODEL-SLOT: periodic duration-model interval

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

PRIVATE>

: update-periodic ( periodic duration -- )
    2dup [ enabled>> ] [ interval-enable? ] bi* and
    [ start-periodic-timer ]
    [ drop stop-periodic-timer ] if ;

! This reacts to changes of a model providing the interval
M: periodic model-changed nip dup interval>> update-periodic ; inline

M: periodic model-activated dup model-changed ;

! Take a model which must have a value as duration.  If that model changes,
! start a timer according to that interval which sets this model's value to t.
: <periodic> ( duration enable -- model )
    swap f periodic new-model swap >>interval swap >>enabled ;

:: ?inc-model ( ? amount model -- value )
    model value>> amount +
    ? [ dup model set-model ] when ;

! Take a model that holds a number, increment it by amount every duration.  Gets
! activated when the output is activated.  Returns a model that is periodically
! updated with the next value.
:: <counter> ( model amount duration -- periodic model )
    duration f <periodic>
    [ ]
    [ [ amount model ?inc-model ] <arrow> ] bi ;

! Counts, but stops if the last value was not the same

:: step-range ( amount range -- max? )
    range range-model :> model
    range range-max-value :> max
    model value>> :> value
    value amount 0 or + :> next
    amount [ range move-by ] when*
    next max >= ;

: range-end? ( value range -- ? )
     range-max-value > ;

! Take a range model, step the value in periodic increments by step size, stop when done.
! :: range-stepper ( range amount interval-duration -- periodic range-end? )
!     interval-duration f <periodic> dup :> periodic
!     [ amount range range-model ?inc-model range
!       range-end? dup [ f periodic enable-model>> set-model ] when ] <arrow>
!     periodic swap
!     ;
