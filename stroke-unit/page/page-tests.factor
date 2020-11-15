USING: accessors kernel sequences stroke-unit stroke-unit.page ui.gadgets ;
IN: stroke-unit.page.tests



: clip-view-test ( -- views parameters gadget time )
    xopp-test nip 10 head initialize-clips
    <page-parameters> 2dup swap first
    <clip-view> nip over current-time>> ;

: page-canvas-test ( -- page-canvas range )
    xopp-test nip 10 head initialize-clips <page-canvas>
    swap
    ;

: page-test ( -- gadget )
    xopp-test nip 10 head <page-viewer> ;

: page-timeline-test ( -- gadget gadget )
    xopp-test nip 10 head initialize-clips [ <page-viewer> ] keep
    <page-timeline> ;

: page-editor-test ( -- gadget )
    xopp-test nip 10 head initialize-clips
    <page-editor> ;
