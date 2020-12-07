USING: accessors calendar io.files.temp io.pathnames kernel math.vectors models
sequences stroke-unit.clips stroke-unit.elements stroke-unit.models.clip-display
stroke-unit.page stroke-unit.util xopp.file ;

IN: stroke-unit.models.project


! clips is a clip-display model when unbaked
TUPLE: project-page page clips ;

: bake-page ( project-page -- project-page )
    [ compute-model bake-clips ] change-clips ;

: unbake-page ( project-page -- project-page )
    [ unbake-clips <model> ] change-clips ;

! pages: live: { path project-page }
TUPLE: project project-path name render-dim pages ;

: <project> ( path name dim -- obj )
    project new
    swap >>render-dim
    swap >>name
    swap >>project-path ;

: project-file-path ( project -- path )
    [ project-path>> ] [ name>> ] bi append-path ".supr" append ;

: save-project ( project -- )
    dup project-path>> ensure-directory drop
    [ clone [ [ clone bake-page ] map ] change-pages ]
    [ project-file-path ] bi
    serialize-bin-file ;

: load-project ( project-file-path -- project )
    deserialize-bin-file [ [ unbake-page ] map ] change-pages ;

: max-page-dim ( pages -- dim )
    [ { 640 480 } ] [ [ page-dim ] [ vmax ] map-reduce ] if-empty ;

: generate-project-filename ( -- str )
    "stroke-unit-" temp-file now timestamp>filename-component append ;

: import-pages ( project pages -- project )
    [ dup page-clips initialize-clips <model> project-page boa ] map >>pages ;

: xopp-file>project ( xopp-file-path -- project )
    generate-project-filename swap
    [ file-stem ]
    [ file>xopp ] bi
    pages
    [ max-page-dim <project> ]
    [ import-pages ] bi ;
