USING: accessors kernel models sequences stroke-unit.elements ui xopp.file ;

USE: stroke-unit.util
USE: stroke-unit.clips
USE: stroke-unit.models.clip-display
USE: stroke-unit.page
IN: stroke-unit

TUPLE: page layers ;
TUPLE: layer clips ;

: xopp-test-file ( -- x )
    "~/xournalpp/uebungen/2.1.xopp" file>xopp ;

: edit-page ( page -- gadget )
    <page-editor>
    gadget-child dup "foo" open-window ;

: xopp-test ( --  editor )
    xopp-test-file
    pages first edit-page ;

: open-page ( path -- gadget )
    f <page-editor> swap [ editor-load ] keepd [ "foo" open-window ] keep gadget-child ;

: empty-page ( -- gadget )
    f <page-editor> dup "foo" open-window gadget-child ;

