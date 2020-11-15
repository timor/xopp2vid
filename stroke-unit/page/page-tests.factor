USING: accessors kernel sequences stroke-unit stroke-unit.page ui.gadgets ;
IN: stroke-unit.page.tests

: test-clips ( -- seq ) xopp-test nip 10 head ;

: clip-view-test ( -- views parameters gadget time )
    test-clips initialize-clips
    <page-parameters> 2dup swap first
    <clip-view> nip over current-time>> ;

: page-canvas-test ( -- page-canvas range )
    test-clips initialize-clips <page-canvas>
    swap
    ;

: page-test ( -- gadget )
    test-clips initialize-clips <page-viewer> ;

: page-timeline-test ( -- gadget gadget )
    test-clips initialize-clips [ <page-viewer> ] keep
    <page-timeline> ;

: page-editor-test ( -- gadget )
    test-clips initialize-clips
    <page-editor> ;
