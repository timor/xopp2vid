USING: accessors kernel sequences stroke-unit stroke-unit.models.page-parameters
stroke-unit.page ui ;
IN: stroke-unit.page.tests

: test-clips ( -- seq )
    "~/xournalpp/uebungen/1.3.xopp" load-xopp-file
    pages first page-clips 10 head ;

: clip-view-test ( -- views parameters gadget time )
    test-clips initialize-clips
    <page-parameters> 2dup swap first
    <clip-view> nip over current-time>> ;

: page-canvas-test ( -- page-canvas range )
    test-clips initialize-clips
    [ <range-page-parameters> ] keep
    <page-canvas> swap ;

! : page-test ( -- gadget )
!     test-clips initialize-clips <page-viewer> ;

! : page-timeline-test ( -- gadget gadget )
!     test-clips initialize-clips [ <page-viewer> ] keep
!     <page-timeline> ;

: page-editor-test ( -- models gadget )
    test-clips
    <page-editor> [ clip-displays>> ] keep ;

: test-editor ( -- models gadget )
    page-editor-test dup "foo" open-window ;
