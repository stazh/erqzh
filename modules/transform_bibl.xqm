xquery version "3.1";

module namespace t-bibl = "http://jinntec.de/ssrq/t_bibl";

declare default element namespace "http://www.tei-c.org/ns/1.0";
declare namespace test = "http://exist-db.org/xquery/xqsuite";

declare variable $t-bibl:bibl := doc('../data/SSRQ_ZH_NF_Bibliographie_integral.xml')//body;

(:~ Updates the provided bibliography file for easier processing and display within the tei-publisher app.
 : !!!NOTE!!! These modifications are permanent
 : @see https://gitlab.existsolutions.com/rqzh/rqzh2/-/issues/96
 : 
 : Three entries should be manually corrected before any further processing.
 : 
 : @see https://gitlab.existsolutions.com/rqzh/rqzh2/-/issues/83#note_19630 
 : @see transform_bibl_spec.xqm
 : 
 : @author Duncan Paterson
 :)




(:~ Take the marc 700 based type, for each biblStruc and add it as attribute instead of inline comment.
 : There are 9 distinct values for the biblStruc type in the data
 : t-bibl:struc-type($bibl//biblStruct) => distinct-values()
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
    let $primary-check := exists($n/following-sibling::title[@type='short'])
    return
        if ($primary-check) then (<title type="full"> {$n/text()} </title>)
        else ($n)
        
};


(:~ Analyze biblScope so that it can be homogenized across the bibliography 
 : @see chbsg000137082 (4 parts)
 :)
declare function t-bibl:analyze-scope($nodes as node()*) as item()*{
    <imprint>
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
    (: Remove strings where we can   :)
    let $clean := replace($token, '(B(an)?d|S)\.?\s*', '')
    (: 50/50 scopes with "S" spot checking suggest those without are usually volumes  :)
    let $type := if (contains($token, "S")) then ('page') else ('volume')
    return
        if (matches($token, '(18|19|20)\d{2}')) 
        then (<date>{$clean}</date>)
        else(<biblScope unit='{$type}'> {$clean} </biblScope>)
        
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
        (   <biblScope unit='issue'>{$t[1]}</biblScope>,
            <date>{$t[2]}</date>,
            t-bibl:scope-1($t[3]))
        
};


(:~ Add missing dates for serials by extracting from biblScope 
 : TODO(DP): Out of scope most should have dates extracted from biblScope but there might be danglers
 :)
declare function t-bibl:add-date($node as node()*) as item()*{
    $node
};

(:~ Non-destructive transformation calling the other functions to modify list 
 : for debugging simply call t-bibl:transform-list($t-bibl:bibl//id('XXX')) with xml:id of item 
 : to see a quick preview of the transformation. 
 : 
 : removes type=edition attributes as these are inconsistently applied, and always put in an invalid location
 : keeps inline comments as is
 : filter invalid and duplicate dates
 : 
 : @param body the body element of the input list
 :)
declare function t-bibl:transform-list($body as node()*) as item()*{
    for $e in $body
    return
        typeswitch($e)
            case text() return ()
            case comment() return $e
            case element (biblStruct) 
                return element {name($e)} {($e/@*, attribute type {t-bibl:struc-type($e)}), t-bibl:transform-list($e/node())}
            case element (title)    
                return (t-bibl:full-title($e), t-bibl:transform-list($e/node())) 
            case element (biblScope)    
                return if ($e/../series or $e/../../analytic)  then (t-bibl:analyze-scope($e), t-bibl:transform-list($e/node()))
                else (t-bibl:analyze-scope($e)/*, t-bibl:transform-list($e/node()))
            case element (monogr)    
                return element {name($e)} {t-bibl:transform-list($e/node())}
            case element (analytic)    
                return element {name($e)} {t-bibl:transform-list($e/node())}      
            case element (author)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (publisher)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (pubPlace)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (date)    
                return if (t-bibl:analyze-scope($e/../biblScope)/date) then ()
                else (element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))})
            case element (note)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (head)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (p)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (ref)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (orgName)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (resp)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}
            case element (idno)    
                return element {name($e)} {($e/@*, $e/text(), t-bibl:transform-list($e/node()))}    
        default return element {name($e)} {($e/@*, t-bibl:transform-list($e/node()))}        

};


(:~ Main transformation calling the other functions to update the list :)
declare 
%private 
function t-bibl:update-list($body as node()*) as item()*{
    let $struc := for $st in $body//biblStruct return update insert attribute type {t-bibl:struc-type($st)} into $st
    let $title := for $t in $body//title return update replace $t with t-bibl:full-title($t)
    let $scope := for $sc in $body//biblScope return update replace $sc with t-bibl:analyze-scope($sc)
    
    return
       $body
};

(: FIXUP :)
(:~ Fix remaining invalid entries.
 : The main transformation will return 16 invalid entries:
 : 
 : ('chbsg991001259148003977', 'chbsg000104927', 'chbsg000151044', 'chbsg000109616', 'chbsg991001261449703977', 
 :   'chbsg000137916', 'chbsg991001261449803977', 'chbsg000151048', 'chbsg000135484', 'chbsg000143814', 'chbsg000134441', 
 :   'chbsg000135489',  'chbsg000134489', 'chbsg000134488', 'chbsg000135490', 'chbsg000105140')
 : 
 : @see t-bibl:store-result()
 : 
 :)
 
 
(:~ delete dates provided on series which is incorrect, and often at odds with the date provided for the bibliographical item :)
declare function t-bibl:fixup-series-dates ($new-doc as node()) as item()*{
    let $bad_ids := ('chbsg991001259148003977', 'chbsg000104927', 'chbsg000151044', 'chbsg000109616', 'chbsg991001261449703977', 
    'chbsg000137916', 'chbsg991001261449803977', 'chbsg000151048', 'chbsg000135484', 'chbsg000143814', 'chbsg000134441', 
    'chbsg000135489',  'chbsg000134489', 'chbsg000134488', 'chbsg000135490')
    
    for $fix in $new-doc/id($bad_ids)
    return
        update delete $fix//series/date
};


declare function t-bibl:fixup-monogr-dates ($new-doc as node()) as item()*{

    let $date := <date>1996</date>
    return
        update insert $date into $new-doc/id('chbsg000105140')//imprint,
        update delete $new-doc/id('chbsg000105140')//monogr/date
};



(:~ Stores the result of transformation into db
 : @param list the input list
 : @param file-name name of new file without .xml ending
 :)
declare function t-bibl:store-result ($list as node()*, $file-name as xs:string) as item() {
    let $header := $list/../../teiHeader
    let $joined := 
    <TEI xmlns:ssrq="http://ssrq-sds-fds.ch/ns/nonTEI" xmlns:xi="http://www.w3.org/2001/XInclude" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" type="biblio" xml:lang="de">
        {$header}
        <text>
        {t-bibl:transform-list($list)}
        </text>
    </TEI>
    return
        xmldb:store('/db/apps/rbibl/data/', $file-name || '.xml', $joined)  
};
