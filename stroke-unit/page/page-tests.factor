USING: kernel sequences stroke-unit stroke-unit.page ;
IN: stroke-unit.page.tests



: clip-view-test ( -- views parameters gadget time )
    xopp-test nip 10 head initialize-clips
    <page-parameters> 2dup swap first
    <clip-view> nip over current-time>> ;

: page-test ( -- page-canvas time )
    xopp-test nip 10 head <page-canvas>
    dup parameters>> current-time>>
    ;
