USING: combinators.smart effects.parser fry generalizations kernel
words ;

IN: stroke-unit.page
DEFER: editor-refocus
IN: stroke-unit.page.syntax
: annotate-editor-command ( def -- def )
    [ inputs ] keep
    '[ _ npick _ dip editor-refocus ] ;
    ! [ keeping editor-refocus ] curry ;


SYNTAX: E: (:) [ annotate-editor-command ] dip define-declared ;
SYNTAX: E:: (::) [ annotate-editor-command ] dip define-declared ;
