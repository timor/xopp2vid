USING: accessors kernel models models.arrow models.selection prettyprint
sequences tools.test ui.gadgets ui.gadgets.buttons ui.gadgets.labels
ui.gadgets.packs ui.gadgets.wrappers ;
IN: models.selection.tests

FROM: ui.gadgets.wrappers => wrapper ;

TUPLE: selection-wrapper < wrapper selection ;
INSTANCE: selection-wrapper has-selection
! M: selection-wrapper multi-select? drop t ;

:: <click-me> ( label model -- button )
    label [ drop label model set-model ]
    <button> ;

:: test-selection-gadget ( -- gadget )
    <pile>
    "BAR" <model> :> disp
    { "foo" "bar" "baz" } <model> <selection> t >>multi? dup :> sel-model
    dup items>>
    [| selection string |
     selection string dup disp <click-me> <selectable-border>
     add-gadget
    ] with each
    disp <label-control> add-gadget
    sel-model selected-model>> [ unparse ] <arrow> <label-control> add-gadget
    selection-wrapper new-wrapper sel-model >>selection
    ;
