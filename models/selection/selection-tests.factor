USING: accessors kernel models models.arrow models.selection prettyprint
sequences tools.test ui.gadgets ui.gadgets.buttons ui.gadgets.labels
ui.gadgets.packs ;
IN: models.selection.tests

:: <click-me> ( label model -- button )
    label [ drop label model set-model ]
    <button> ;

:: test-selection-gadget ( -- gadget )
    <pile>
    "BAR" <model> :> disp
    { "foo" "bar" "baz" }
    [ <model> ] keep over :> sel-model
    [| selection-model string |
     selection-model string dup disp <click-me> <selectable-border> t >>multi
     add-gadget
    ] with each
    disp <label-control> add-gadget
    sel-model [ unparse ] <arrow> <label-control> add-gadget
    ;
