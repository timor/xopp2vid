USING: kernel sequences stroke-unit.elements ui ui.gadgets vocabs.parser
xopp.file ;

USE: stroke-unit.util
USE: stroke-unit.clips
USE: stroke-unit.models.clip-display
USE: stroke-unit.page
IN: stroke-unit

TUPLE: page layers ;
TUPLE: layer clips ;

: xopp-test-file ( -- x )
    "~/xournalpp/uebungen/2.1.xopp" file>xopp ;

: edit-single-page ( page -- gadget )
    <page-editor>
    gadget-child dup "foo" open-window ;

: xopp-test ( --  editor )
    xopp-test-file
    pages first edit-single-page ;

: open-page ( path -- gadget )
    f <page-editor> swap [ editor-load ] keepd [ "foo" open-window ] keep gadget-child ;

: empty-page ( -- gadget )
    f <page-editor> dup "foo" open-window gadget-child ;

: run-stroke-unit ( -- )
    [ [ f <page-editor> "Stroke Unit" open-window ] with-ui ] with-manifest ;
MAIN: run-stroke-unit
