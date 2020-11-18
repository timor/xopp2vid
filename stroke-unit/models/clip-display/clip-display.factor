USING: accessors calendar kernel locals math math.functions math.order models
models.arrow models.arrow.smart models.product namespaces sequences
sequences.generalizations stroke-unit.clips ;

IN: stroke-unit.models.clip-display
FROM: models.product => product ;

TUPLE: clip-display < product ;
SLOT: prev
SLOT: clip
SLOT: start-time
SLOT: stroke-speed
SLOT: draw-duration

! All parameters models
: new-clip-display ( prev clip start-time stroke-speed draw-duration -- model )
    5 narray clip-display new-product ;

M: clip-display prev>> dependencies>> first ;
M: clip-display clip>> dependencies>> second ;
M: clip-display start-time>> dependencies>> third ;
M: clip-display stroke-speed>> dependencies>> fourth ;
M: clip-display draw-duration>> dependencies>> 4 swap nth ;

SYMBOL: no-predecessor-clip
no-predecessor-clip
[ f <model> f <model> 0 <model> f <model> instant <model> new-clip-display ] initialize

: <draw-speed--> ( duration-model clip-model -- speed-model )
    [ [ duration>seconds ] [ clip-move-distance ] bi* swap / ]
    <smart-arrow> ;

: clip-draw-duration ( clip stroke-speed -- duration )
    [ clip-move-distance ] dip / seconds ;

! For updating display from speed parameter
: <draw-duration--> ( clip-model stroke-speed-model -- duration-model )
    [ clip-draw-duration ] <smart-arrow> ;

: <stroke-speed--> ( clip-model draw-duration-model -- stroke-speed-model )
    [ [ clip-move-distance ] dip duration>seconds 0.001 max / ] <?smart-arrow> ;

: compute-start-time ( prev-clip -- seconds )
    [ [ start-time>> compute-model ] [ draw-duration>> compute-model ] bi duration>seconds + ]
    [ 0 ] if* ;

TUPLE: model-model < model saved-model ;
! Caveat: the contained model is always activated
<PRIVATE
: disconnect-old ( model-model -- )
    dup saved-model>>
    [ remove-connection ] [ drop ] if* ;
: connect-new ( model-model -- )
    dup value>> add-connection ;
PRIVATE>
M: model-model update-model
    [ disconnect-old ]
    [ connect-new ]
    [ [ value>> ] keep saved-model<< ] tri ;
M: model-model model-changed
    nip notify-connections ;

: <model-model> ( model -- model-model )
    f model-model new-model
    [ set-model ] keep ;

! TODO This would maybe easier if there was a generic on deactivation
: deactivate-model-model ( model-model -- )
    disconnect-old ;

! Set up start time from model of previous clip-display
: <start-time--> ( prev-clip-display -- time-model )
    [ compute-start-time ] <?arrow> ;

! f is valid between 0.0 and 1.0
: float-nth ( f seq -- elt )
    [ 0 1 clamp ] dip
    [ length 1 - * floor >integer ]
    [ nth ] bi ; inline

! Creating the actual model container
:: <clip-display> ( clip initial-stroke-speed -- obj )
    no-predecessor-clip get <model-model> :> prev-model
    clip <model> :> clip-model
    clip initial-stroke-speed clip-draw-duration <model> :> draw-duration-model
    ! clip-model speed-model <draw-duration--> :> draw-duration-model
    clip-model draw-duration-model <stroke-speed--> :> speed-model
    prev-model <start-time--> :> start-time-model
    prev-model clip-model start-time-model speed-model draw-duration-model new-clip-display ;

: connect-clip-displays ( clip-display1 clip-display2 -- )
    prev>> ?set-model ;

! TODO Needed?
: set-clip ( clip clip-display -- )
    clip>> set-model ;

TUPLE: pause-display < clip-display ;
:: <pause-display> ( initial-duration -- obj )
    no-predecessor-clip get <model-model>
    <empty-clip> <model> over <start-time--> 0 <model> initial-duration <model> new-clip-display ;
