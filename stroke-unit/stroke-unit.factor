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

: edit-page ( page -- gadget )
    <page-editor>
    dup "foo" open-window ;

: xopp-test ( --  editor )
    xopp-test-file
    pages first edit-page ;

: open-page ( path -- gadget )
    f <page-editor> swap [ editor-load ] keepd [ "foo" open-window ] keep ;

: empty-page ( -- gadget )
    f <page-editor> dup "foo" open-window ;

: page1 ( -- gadget )
    "~/ra1-video/aufgabe2.1p1.suc" open-page
    xopp-test-file pages first >>page ;

: page2 ( -- gadget )
    "~/ra1-video/aufgabe2.1p2.suc" open-page
    xopp-test-file pages second >>page ;

: page3 ( -- gadget )
    "~/ra1-video/aufgabe2.1p3.suc" open-page
    xopp-test-file pages second >>page ;

: load-2.4 ( -- xml )
    "~/xournalpp/uebungen/2.4.xopp" load-xopp-file ;

: edit-2.4 ( -- gadget )
    "~/ra1-video/aufgabe2.4.suc" open-page
    "~/ra1-video/aufgabe2.4" >>output-dir
    load-2.4 pages first >>page
    ;
