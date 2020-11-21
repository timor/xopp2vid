USING: calendar formatting kernel models models.arrow tools.test ui.gadgets
ui.gadgets.labels ui.gadgets.timeline ;
IN: ui.gadgets.timeline.tests

: <duration-label> ( model -- gadget )
    [ "%.2f" sprintf ] <arrow> <label-control> ;

: test-timeline ( -- gadget )
    20 1 vertical <timeline>
    60 <model> [ <duration-label> ] keep timeline-add
    30 <model> [ <duration-label> ] keep timeline-add
    90 <model> [ <duration-label> ] keep timeline-add
    <scroller> ;
