USING: accessors arrays io.directories kernel math math.combinators
math.functions math.order models models.arrow models.arrow.smart
models.model-slots models.product namespaces sequences sequences.generalizations
sets stroke-unit.clip-renderer stroke-unit.clips ;

IN: stroke-unit.models.clip-display
FROM: models.product => product ;

TUPLE: clip-display < product ;
MODEL-SLOT: clip-display [ dependencies>> first ] prev
MODEL-SLOT: clip-display [ dependencies>> second ] clip
MODEL-SLOT: clip-display [ dependencies>> third ] start-time
MODEL-SLOT: clip-display [ dependencies>> fourth ] stroke-speed
MODEL-SLOT: clip-display [ dependencies>> 4 swap nth ] draw-duration

! All parameters models
: new-clip-display ( prev clip start-time stroke-speed draw-duration -- model )
    5 narray clip-display new-product ;

SYMBOL: no-predecessor-clip
no-predecessor-clip
[ f <model> f <model> 0 <model> f <model> 0 <model> new-clip-display ] call swap set-global

: <draw-speed--> ( duration-model clip-model -- speed-model )
    [ [ ] [ clip-move-distance ] bi* swap / ]
    <smart-arrow> ;

: clip-draw-duration ( clip stroke-speed -- duration )
    [ clip-move-distance ] dip / ;

! For updating display from speed parameter
! Unused, draw duration is model graph source
: <draw-duration--> ( clip-model stroke-speed-model -- duration-model )
    [ clip-draw-duration ] <smart-arrow> ;

: <stroke-speed--> ( clip-model draw-duration-model -- stroke-speed-model )
    [ [ clip-move-distance ] dip 0.001 max / ] <?smart-arrow> ;

: compute-start-time ( prev-clip -- seconds )
    [ [ start-time!>> ] [ draw-duration!>> ] bi + ]
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

:: <duration-clip-display> ( clip initial-duration -- obj )
    no-predecessor-clip get <model-model> :> prev-model clip
    <model> :> clip-model initial-duration <model>
    :> draw-duration-model clip-model draw-duration-model
    <stroke-speed-->
    :> speed-model prev-model <start-time--> :> start-time-model
    prev-model clip-model start-time-model speed-model
    draw-duration-model new-clip-display ;

: clone-clip-display ( clip-display -- clip-display' )
    [ clip>> ] [ draw-duration>> ] bi
    <duration-clip-display> ;


: connect-clip-displays ( clip-display1 clip-display2 -- )
    ?prev<< ;
    ! prev>> ?set-model ;

:: <pause-display> ( initial-duration -- obj )
    no-predecessor-clip get <model-model>
    <empty-clip> <model> over <start-time--> 0 <model> initial-duration <model> new-clip-display ;

: pause-display? ( clip-display -- ? )
    clip!>> empty-clip? ;

: assign-clip-audio ( clip-display path -- )
    swap [ swap >>audio-path f >>audio ] change-clip drop ;

: assign-audio-dir ( clip-displays path -- )
    qualified-directory-files [ assign-clip-audio ] 2each ;

: set-stroke-speed ( stroke-speed clip-display -- )
    [ clip>> swap clip-draw-duration ]
    [ draw-duration<< ] bi ;

: fit-audio-pause ( clip-display -- seconds/f )
    [ clip>> clip-audio-duration ]
    [ draw-duration!>> ] bi - dup 0 > [ drop f ] unless ;

: extend-duration ( clip-display seconds --  )
    swap [ swap + ] change-draw-duration drop ;

: extend-end-to ( clip-display seconds -- )
    over start-time!>> -
    [ swap draw-duration<< ] [ 2drop ] if-positive ;

: has-audio? ( clip-display -- path/f )
    clip>> audio-path>> dup +no-audio+? [ drop f ] when ;

: delete-strokes ( clip-display strokes -- )
    '[ [ _ diff ] change-elements ] change-clip drop ;

: remove-strokes ( clip-display strokes -- clip-display' )
    [ delete-strokes ] [ [ clone-clip-display <empty-clip> ] dip >>elements >>clip  ] 2bi ;

! * Sequence modification

: start-clip? ( clip -- ? )
    prev>> not ;

: first-clip? ( clip -- ? )
    prev>> start-clip? ;

: connect-insert-nth ( clip n clip-displays -- clip-displays )
    [ [ 1 - ] dip ?nth [ swap connect-clip-displays ] [ drop ] if* ]
    [ ?nth [ connect-clip-displays ] [ drop ] if* ]
    [ insert-nth ] 3tri ;

: insert-clip-before ( clip old clip-displays -- clip-displays )
    [ index ] [ connect-insert-nth ] bi ;

: append-clip ( clip clip-displays -- clip-displays )
    [ 1array ] [ [ length ] keep connect-insert-nth ] if-empty ;

! Special case: we can insert after the start clip
: insert-after-index ( clip seq -- n )
    over start-clip? [ 2drop 0 ]
    [ index 1 + ] if ;

: insert-clip-after ( clip old clip-displays -- clip-displays )
    [ insert-after-index ] [ connect-insert-nth ] bi ;

: find-successor ( clip clip-displays -- clip/f )
    [ prev>> = ] with find nip ;

: disconnect-prev ( clip -- )
    no-predecessor-clip get swap connect-clip-displays ;

: remove-clip ( clip clip-displays -- clip-displays )
    [ drop [ prev>> ] [ disconnect-prev ] bi ]
    [ find-successor [ connect-clip-displays ] [ drop ] if* ]
    [ remove ] 2tri ;

: replace-clip ( clip old clip-displays -- clip-displays )
    [ drop prev>> ]
    [ remove-clip ] 2bi insert-clip-after ;

: extract-strokes ( clip-displays strokes -- clip-display )
    [ [ delete-strokes ] curry each ]
    [ <empty-clip> swap >>elements stroke-speed get <clip-display> ] bi ;
