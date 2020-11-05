USING: definitions math memoize.scoped namespaces tools.test ;

IN: memoize.scoped.tests

SYMBOL: test-counter

: foo* ( x -- x ) test-counter counter + ; memo-scope
: foo ( -- x ) 0 foo* ;

: reset-test ( -- ) f test-counter set-global ;

{ 1 2 3 } [ reset-test 3 [ foo ] times ] unit-test
{ 1 1 1 } [ reset-test { foo* } [ 3 [ foo ] times ] with-memo-scope ] unit-test

[ { + } [ 1 2 + ] with-memo-scope ] [ not-a-scoped-memoized-word? ] must-fail-with

{ 1 1 2 } [ reset-test { foo* } [ foo foo ] with-memo-scope foo ] unit-test

{ 1 1 2 2 3 } [ reset-test { foo* }
              [ foo foo \ foo* reset-memo-scope foo foo ] with-memo-scope foo ] unit-test

{ 1 2 } [ reset-test \ foo* reset-memo-scope foo foo ] unit-test

{ 1 2 2 3 3 2 4 }
[ reset-test
  foo
  { foo* } [ foo foo
             { foo* } [ foo foo ] with-memo-scope
             foo
           ] with-memo-scope foo ] unit-test

{ [ test-counter counter + ] } [ \ foo* definition ] unit-test

! Doesn't work
! \ : 1array [ \ foo* definer ] unit-test

! HOW do you test lexer errors??
! [ "USING: memoize memoize.scoped ; IN: memoize.scoped.tests MEMO: memo-foo ( x -- x ) ; memo-scope" eval( -- ) ]
! [ already-memoized? ] must-fail-with

! [ "USING: memoize.scoped ; IN: memoize.scoped.tests GENERIC: generic-foo ( x -- x ) ; memo-scope" eval( -- ) ]
! [ "not implemented" = ] must-fail-with
