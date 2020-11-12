USING: accessors combinators fry kernel locals math models models.arrow timers
ui.gadgets ui.gadgets.buttons ui.gadgets.labels ui.gadgets.packs
ui.gadgets.sliders ;

IN: controls.animation

SINGLETONS: paused running finished ;

GENERIC: set-model-value ( model animation -- )
GENERIC: rewind-model-value ( model animation -- )
TUPLE: animation < tuple model last timer delay state on-change ;

: notify-state ( animation state -- )
    swap on-change>> [ call( x -- ) ] [ drop ] if* ;

: set-state ( animation state -- )
    2dup swap state>> set-model
    notify-state ;

: animation-finished? ( animation -- ? )
    [ model>> value>> ] [ last>> ] bi = ;

:: make-timer ( animation -- timer )
    animation { [ model>> ] [ delay>> ] } cleave
    :> ( model delay )
    [
        model value>> dup :> value animation last>> =
        [ animation timer>> stop-timer
          animation finished set-state
        ]
        [ value clone animation last<<
          model animation set-model-value
        ] if
    ] f delay <timer> ;

: start-animation ( animation -- )
    [ running set-state ]
    [ timer>> start-timer ] bi ;

: stop-animation ( animation -- )
    [ timer>> stop-timer ]
    [ paused set-state ] bi ;

: new-animation ( model delay class -- obj )
    new swap >>delay swap >>model paused <model> >>state
    dup make-timer >>timer ;

<PRIVATE
: button-label ( animation -- gadget )
    state>> [ running? "⏸" "⯈" ? ] <arrow> <label-control> ;

GENERIC: on-button-press ( animation state -- )
M: paused on-button-press drop start-animation ;
M: running on-button-press drop stop-animation ;
M: finished on-button-press drop
    [ [ model>> ] keep rewind-model-value ]
    [ start-animation ] bi ;

: playback-button ( animation -- gadget )
    [ button-label ] keep '[ drop _ dup state>> value>> on-button-press ] <button> ;

: step-slider-line ( range -- step ) range-step value>> ;

PRIVATE>

! HACK: activating and deactivating the range max sub-model because it is needed during layout*
: precalc-range-max ( model -- )
    range-max [ activate-model ] [ deactivate-model ] bi ;

: <animation-controls> ( animation -- gadget )
    <shelf> swap [ playback-button add-gadget ]
    [ model>> dup precalc-range-max
      [ horizontal <slider> ] [ step-slider-line >>line ] bi add-gadget ] bi ;

TUPLE: range-animation < animation step ;
M: range-animation set-model-value
    over [ step>> ] [ range-value + ] bi* swap
    set-range-value ;
M: range-animation rewind-model-value
    drop [ range-min-value ] [ set-range-value ] bi ;

: <range-animation> ( range delay step -- obj )
    [ range-animation new-animation ] dip >>step ;

: rewind-animation ( animation -- )
    [ model>> ] keep rewind-model-value ;
