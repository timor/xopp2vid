USING: accessors io.pathnames kernel sequences stroke-unit.models.project
stroke-unit.page stroke-unit.util ui.gadgets.books ui.gadgets.colon-wrapper ;

IN: stroke-unit.editor

! * Top-Level interface gadget

TUPLE: project-editor < book project ;

! : <edit-project> ( project-file-path -- gadget )

: <project-page-editor> ( project i -- gadget )
    swap pages>> nth
    [ clips>> <page-editor-from-clips> ]
    [ page>> >>page ] bi \ page-editor swap <colon-wrapper> ;

: setup-project-paths ( gadget project -- gadget )
    project-file-path "out" append-path >>output-dir ;

: edit-project-page ( project i -- gadget )
    [ <project-page-editor> show-editor ] keepd
    setup-project-paths ;
