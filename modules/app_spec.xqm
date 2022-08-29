xquery version "3.1";
(:~ This library module contains XQSuite tests for the app module.
 : Since the input fails to validate the transformation attempts to correct most mistakes.
 :
 : @author Duncan Paterson
 : @version 2.10.1
 :)
 
module namespace a-spec = "http://jinntec.de/ssrq/a-spec";

import module namespace app="http://existsolutions.com/ssrq/app"  at "app.xql";

declare namespace test="http://exist-db.org/xquery/xqsuite";
declare namespace tei="http://www.tei-c.org/ns/1.0";


declare
    %test:name('EV single scope')
    %test:args('chbsg000138256')
    %test:assertEquals(', Berlin 2007, 400–413')
    function a-spec:ev-1-scope($item-id) {
        
        for $s in $app:LITERATUR//id($item-id)
        return
             app:bibl-ev-imprint($s)
};

declare
    %test:name('EV multi scope')
    %test:args('chbsg000133908')
    %test:assertEquals(',  1956, 5–27')
    function a-spec:ev-n-scope($item-id) {
        
        for $s in $app:LITERATUR//id($item-id)
        return
             app:bibl-ev-imprint($s)
};

declare
    %test:name('JA single scope')
    %test:args('chbsg000144840')
    %test:assertEquals(', 1953, 251–313')
    function a-spec:ja-1-scope($item-id) {
        
        for $s in $app:LITERATUR//id($item-id)
        return
             app:bibl-ja-imprint($s)
};

(:see https://gitlab.existsolutions.com/rqzh/rqzh2/-/issues/83#note_19473 :)
declare
    %test:name('JA multi scope')
    %test:args('chbsg000045808')
    %test:assertEquals('126, 2006, 195–217')
    function a-spec:ja-n-scope($item-id) {
        
        for $s in $app:LITERATUR//id($item-id)
        return
             app:bibl-ja-imprint($s)
};