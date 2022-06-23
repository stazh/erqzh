xquery version "3.1";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace t-bibl ="http://jinntec.de/ssrq/t_bibl";

declare variable $bibl := doc('../data/SSRQ_ZH_NF_Bibliographie_integral.xml')//tei:body;

(:~ Updates the provided bibliography file for easier processing and display within the tei-publisher app.
 : !!!NOTE!!! These modifications are permanent
 : @see https://gitlab.existsolutions.com/rqzh/rqzh2/-/issues/96
 : @author Duncan Paterson
 :)


(:~ Take the marc 700 based type, for each biblStruc and add it as attribute instead of inline comment.
 : There are 9 distinct values for the biblStruc type in the data
 : t-bibl:struc-type($bibl//tei:biblStruct) => distinct-values()
 :)
declare function t-bibl:struc-type($nodes as node()*) as xs:string* {
    for $n in $nodes
    let $type := normalize-space($n//comment()[1])
    return
        if (starts-with($type, 'Selbständige')) then ('W')
        else if (starts-with($type, 'Monographie')) then ('W')
        else if (starts-with($type, 'Thesis')) then ('W')
        else if (starts-with($type, 'Unselbständige')) then ('EV')
        else if (contains($type, 'Zeitschrift')) then ('JA')
        else if (contains($type, 'Sammelband')) then ('EV')
        else ($type)

};


(:~ Add a type='full' attribute to the full title, parallel to type='short' for the short title 
 : @see chbsg991001262639603977
 :)
declare function t-bibl:full-title($nodes as node()*) as item()*{
    for $n in $nodes
    (: type='edition' attribute appears only 104 times in 831, therefore we rely on following-sibling  :)
    let $primary-check := exists($n/following-sibling::tei:title[@type='short'])
    return
        if ($primary-check) then (<title xmlns="http://www.tei-c.org/ns/1.0" type="full"> {$n/text()} </title>)
        else ($n)
        
};


(:~ Analyze biblScope so that it can be homogenized across the bibliography 
 : @see chbsg000137082 (4 parts)
 :)
declare function t-bibl:analyze-scope($nodes as node()*) as item()*{
    <imprint xmlns="http://www.tei-c.org/ns/1.0">
    { for $n in $nodes
    let $test := count(tokenize($n, ','))
    return
        switch($test)
            (: 301 :)
            case 1 return t-bibl:scope-1($n/string())
            (: 64 :)
            case 2 return t-bibl:scope-2($n)
            (: 142 :)    
            case 3 return t-bibl:scope-3($n)
        (:  5 itmes with more than 3:)
        default return $n }
    </imprint>
};

(:~ Add unit attribute to single scope elements
 : by removing localizable strings from element contents 
 : TODO(DP): what is 'NF' and should it be a volume or its own thing
 :)
declare function t-bibl:scope-1($scope as xs:string?) as element(bibleScope)*{
    
    let $token := tokenize($scope, ',') ! normalize-space()
    (: Remove strings where we an   :)
    let $clean := replace($token, '(B(an)?d|S)\.?\s*', '')
    (: 50/50 scopes with "S" spot checking suggest those without are usually volumes  :)
    let $type := if (contains($token, "S")) then ('page') else ('volume')
    return
        if (matches($token, '(18|19|20)\d{2}')) 
        then (<date xmlns="http://www.tei-c.org/ns/1.0">{$clean}</date>)
        else(<biblScope xmlns="http://www.tei-c.org/ns/1.0" unit='{$type}'> {$clean} </biblScope>)
        
};

(:~ Split scope where biblScope contains 2 types
 : @see chbsg000151121 :)
declare function t-bibl:scope-2($node as node()*) as item()*{
    tokenize($node, ',') ! normalize-space() ! t-bibl:scope-1(.)

};

(:~ Split scope where biblScope contains 3 types 
 : @see chbsg000138125 :)
declare function t-bibl:scope-3($node as node()*) as item()*{
    let $t := tokenize($node, ',') ! normalize-space()
    return
        (   <biblScope xmlns="http://www.tei-c.org/ns/1.0" unit='issue'>{$t[1]}</biblScope>,
            <date xmlns="http://www.tei-c.org/ns/1.0">{$t[2]}</date>,
            t-bibl:scope-1($t[3]))
        
};


(:~ Add missing dates for serials by extracting from biblScope 
 : TODO(DP): Out of scope most should have dates extracted from biblScope but there might be danglers
 :)
declare function t-bibl:add-date($node as node()*) as item()*{
    $node
};

(:~ Main transformation calling the other functions to update the list :)
declare function t-bibl:transform-list($body as node()*) as item()*{
    let $struc := for $st in $body//tei:biblStruct return update insert attribute type {t-bibl:struc-type($st)} into $st
    let $title := for $t in $body//tei:title return update replace $t with t-bibl:full-title($t)
    let $scope := for $sc in $body//tei:biblScope return update replace $sc with t-bibl:analyze-scope($sc)
    
    return
       $body
};

let $struc-types := t-bibl:struc-type($bibl//tei:biblStruct) => distinct-values()

return
    t-bibl:transform-list($bibl)
