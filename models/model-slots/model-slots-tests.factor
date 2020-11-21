! Copyright (C) 2020 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors kernel math models models.arrow models.model-slots tools.test ;
IN: models.model-slots.tests



TUPLE: has-model foo-m ;
MODEL-SLOT: has-model [ foo-m>> ] foo

: <has-model> ( model -- obj )
    has-model boa ; inline

[ has-model new foo>> ] must-fail
{ 47 } [ 47 <model> <has-model> foo>> ] unit-test
{ 48 } [ 48 <model> <has-model> foo!>> ] unit-test
{ t } [ 42 <model> dup <has-model> foo-model>> eq? ] unit-test
{ 50 } [ 49 <model> <has-model> [ 50 swap foo<< ] [ foo>> ] bi ] unit-test
{ 52 } [ 51 <model> <has-model> [ 1 + ] change-foo foo>> ] unit-test
{ f } [ 53 <model> [ 1 + ] <arrow> <has-model> foo>> ] unit-test
{ 56 } [ 55 <model> [ 1 + ] <arrow> <has-model> foo!>> ] unit-test
{ 57 } [ f <model> <has-model> 57 >>foo foo>> ] unit-test
