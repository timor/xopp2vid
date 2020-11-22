USING: accessors colors ui.gadgets ui.gadgets.border-handles ui.pens.solid ;

IN: ui.gadgets.border-handles.tests

: test-gadget ( -- gadget )
    <gadget>
    <gadget> 0 0 0 0.5 <rgba> <solid> >>interior
    +east+ border-handle new-border-handle
    { 200 200 } >>dim ;
