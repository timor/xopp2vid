USING: accessors kernel math.rectangles models ui.gadgets ui.gadgets.wrappers ;

IN: ui.gadgets.wrappers.rect-wrappers
FROM: ui.gadgets.wrappers => wrapper ;

! Model: it's own rect
TUPLE: rect-wrapper < wrapper ;
M: rect-wrapper model-changed
    [ value>> rect-bounds ] dip
    [ [ dim<< ] [ loc<< ] bi ] [ relayout ] bi ;
M: rect-wrapper pref-dim*
    model>> compute-model dim>> ;

: <rect-wrapper> ( model gadget -- gadget )
    rect-wrapper new-wrapper swap >>model ;

