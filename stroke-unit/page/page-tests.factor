USING: kernel sequences stroke-unit stroke-unit.page ;
IN: stroke-unit.page.tests



: clip-view-test ( -- views parameters gadget time )
    xopp-test nip 10 head initialize-clips
    <page-parameters> 2dup swap first
    <clip-view> nip over current-time>> ;

: page-canvas-test ( -- page-canvas range )
    xopp-test nip 10 head <page-canvas>
    swap
    ;

: page-test ( -- gadget )
    xopp-test nip 10 head <page-viewer> ;
