USING: accessors calendar fry kernel literals math math.order models sequences
timers ;

IN: models.periodic

SLOT: interval
TUPLE: periodic < model
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

PRIVATE>

: update-periodic ( periodic duration -- )
    dup interval-enable?
    [ start-periodic-timer ]
    [ drop stop-periodic-timer ] if ;

! Sets the interval of a periodic to obj, update.
GENERIC: set-periodic-interval ( periodic obj -- )
M: model set-periodic-interval
    over dup duration-model>> [ remove-connection ] [ drop ] if*
    [ add-connection ] [ swap model-changed ] 2bi ;
M: duration set-periodic-interval <model> set-periodic-interval ;
M: f set-periodic-interval <model> set-periodic-interval ;

M: periodic interval<< swap set-periodic-interval ;
M: periodic interval>> duration-model>> value>> ;

! This reacts to changes of a model providing the interval
M: periodic model-changed swap value>> update-periodic ; inline

M: periodic model-activated [ dependencies>> ] keep [ model-changed ] curry each ;

! Take a model which must have a value as interval.  If that interval changes,
! start a timer according to that interval which sets this model's value to t.
: <periodic> ( duration/model -- model )
    f periodic new-model swap >>interval ;
