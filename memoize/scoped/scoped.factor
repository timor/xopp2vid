USING: accessors assocs definitions effects fry generic kernel locals math
memoize memoize.private namespaces sequences words ;

IN: memoize.scoped

TUPLE: memo-key ;
C: <memo-key> memo-key
PREDICATE: scoped-memoized < memoized "memoize" word-prop memo-key? ;

! We want to behave like memoized Except if it's about the definer
M: scoped-memoized definer memoized \ definer next-method execute( defspec -- start end ) ;

:: cache-or-call ( ... key assoc quot: ( ... key -- ... value ) -- ... value )
    assoc
    [ key assoc quot cache ] quot '[ key @ ] if ; inline

: scoped-make/n ( token quot effect -- quot )
    [ unpack/pack '[ _ get _ cache-or-call ] ] keep pack/unpack ;

: scoped-make/0 ( word quot effect -- quot )
    "sorry, not implemented yet" throw ;

: make-scoped-memoizer ( token quot effect -- quot )
    dup in>> length zero? [ scoped-make/0 ] [ scoped-make/n ] if ;

:: (make-scope-memoized) ( word effect -- )
    word def>> :> quot
    word quot "memo-quot" set-word-prop
    <memo-key> :> token
    word token "memoize" set-word-prop
    token quot effect make-scoped-memoizer word def<< ;

GENERIC: make-scope-memoized ( word -- )
ERROR: already-memoized word ;
M: memoized make-scope-memoized already-memoized ;
M: word make-scope-memoized
    dup stack-effect (make-scope-memoized) ;
M: generic make-scope-memoized "not implemented" throw ;

! TODO: we don't do a changed-definition here because we assume that it just has been defined
SYNTAX: memo-scope
    last-word make-scope-memoized ;

ERROR: not-a-scoped-memoized-word word ;
GENERIC: get-memo-key ( word -- var )
M: object get-memo-key not-a-scoped-memoized-word ;
M: scoped-memoized get-memo-key "memoize" word-prop ; inline

: init-memo-scope-entry ( assoc word -- assoc )
    get-memo-key H{ } clone swap pick set-at ;

: with-memo-scope ( words quot -- )
    [ H{ } clone swap [ init-memo-scope-entry ] each ] dip with-variables ; inline

GENERIC: reset-memo-scope ( word -- )

M: scoped-memoized reset-memo-scope
    get-memo-key get clear-assoc ;
