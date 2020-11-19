USING: accessors kernel models sequences stroke-unit.elements ui xopp.file ;

USE: stroke-unit.util
USE: stroke-unit.clips
USE: stroke-unit.models.clip-display
USE: stroke-unit.page
IN: stroke-unit

TUPLE: project path pages ;
TUPLE: page layers ;
TUPLE: layer clips ;

: load-xopp-file ( path -- xml )
    file>xopp ;

: xopp-test-file ( -- x )
    "~/xournalpp/uebungen/2.1.xopp" load-xopp-file ;

: xopp-test ( --  editor )
    xopp-test-file
    pages first <page-editor>
    dup "foo" open-window ;

: open-page ( path -- gadget )
    f <page-editor> swap [ editor-load ] keepd [ "foo" open-window ] keep ;

: empty-page ( -- gadget )
    f <page-editor> dup "foo" open-window ;
