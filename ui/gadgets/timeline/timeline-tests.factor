USING: calendar formatting kernel models models.arrow tools.test ui.gadgets
ui.gadgets.labels ui.gadgets.timeline ;
IN: ui.gadgets.timeline.tests

: <duration-label> ( model -- gadget )
    [ duration>seconds "%.2f" sprintf ] <arrow> <label-control> ;

: test-timeline ( -- gadget )
    5 1 vertical <timeline>
    60 seconds <model> [ <duration-label> ] keep timeline-add
    30 seconds <model> [ <duration-label> ] keep timeline-add
    90 seconds <model> [ <duration-label> ] keep timeline-add
    <scroller> ;
