USING: accessors kernel ui.gadgets ui.gadgets.colon-wrapper ui.pens.solid ;

IN: ui.gadgets.colon-wrapper.tests

TUPLE: test-gadget < gadget ;

M: test-gadget pref-dim* drop { 100 100 } ;

: change-color ( gadget color -- )
    <solid> >>interior relayout ;

: test-colon-wrapper ( -- gadget )
    test-gadget dup new <colon-wrapper> ;
