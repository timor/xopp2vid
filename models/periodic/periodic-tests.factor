USING: calendar kernel locals models models.arrow models.periodic models.range
prettyprint ui.gadgets ui.gadgets.labels ui.gadgets.packs ui.gadgets.sliders ;
IN: models.periodic.tests

: test-counter ( -- periodic gadget )
    0 <model> 1 1 seconds <counter> [ unparse ] <arrow> <label-control> ;

:: test-setup ( -- periodic pile )
    0 0 0 50 1 <range> :> range
    range 1 1 seconds range-stepper :> ( periodic range-end? )
    <pile> range horizontal <slider> add-gadget
    range-end? [ unparse ] <arrow> <label-control> add-gadget :> p
    periodic p ;
