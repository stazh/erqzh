(:
 :
 :  Copyright (C) 2017 Wolfgang Meier
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.1";

module namespace teis="http://www.tei-c.org/tei-simple/query/tei";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei" at "navigation-tei.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";

declare variable $teis:REFERENCED_DOCS := collection($config:data-root)//tei:div[@type='collection']//tei:ref/string();

declare function teis:filter-collections($docs) {
    for $doc in $docs
    where not(ft:field($doc, 'idno') = $teis:REFERENCED_DOCS)
    return
        $doc
};

declare function teis:query-default($fields as xs:string+, $query as xs:string, $target-texts as xs:string*,
    $sortBy as xs:string*) {
    if(string($query)) then
        for $field in $fields
        return
            switch ($field)
                case "head" return
                    if (exists($target-texts)) then
                        for $text in $target-texts
                        return
                            $config:data-root ! doc(. || "/" || $text)//tei:head[ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-root)//tei:head[ft:query(., $query, query:options($sortBy))]
                default return
                    if (exists($target-texts)) then
                        for $text in $target-texts
                        let $divisions := $config:data-root ! doc(. || "/" || $text)//tei:div[ft:query(., $query, query:options($sortBy))]
                        return
                            if (empty($divisions)) then
                                $config:data-root ! doc(. || "/" || $text)//tei:text[ft:query(., $query, query:options($sortBy))]
                            else
                                $divisions
                    else
                        let $divisions := collection($config:data-root)//tei:div[ft:query(., $query, query:options($sortBy))]
                        return
                            if (empty($divisions)) then
                                collection($config:data-root)//tei:text[ft:query(., $query, query:options($sortBy))]
                            else
                                $divisions
    else ()
};

declare function teis:query-metadata($path as xs:string?, $field as xs:string?, $query as xs:string?, $sort as xs:string) {
    (: let $_ := util:log("info",   map {
            "name":"teis:query-metadata", 
            "fielld":$field, 
            "$query":$query, 
            "$sort":$sort
    }) :)
    let $subfields := request:get-parameter("subtype", "text")
    let $queryExpr := 
        if ($field = "file" or empty($query) or $query = '') then 
            "corpus:rqzh AND NOT type:variant" 
        else
            "(" || teis:query-by-subfield($subfields, $query) || ") AND NOT type:variant"
    let $options := query:options($sort, $subfields)
    let $_ := util:log("info", map {"name":"teis:query-metadata", "$queryExpr":$queryExpr, "$options":$options})
    let $result :=
        $config:data-default ! (
            collection(. || "/" || $path)//tei:text[ft:query(., $queryExpr , $options)]
        ) 
   (: let $_ := util:log("info", map {"name":"teis:query-metadata", "result-count:":count($result)}) :)

    return
        query:sort(teis:filter-by-date($result), $sort)
};

declare function teis:query-by-subfield($fields as xs:string*, $query as xs:string?) {
    string-join(
        for $field in $fields
        return
            (if ($field = "edition") then "text" else $field) || ":(" || $query || ")",
        " OR "
    )
};

declare function teis:filter-by-date($result) {
    let $minDate := teis:normalize-date(request:get-parameter("date-min", ()), ())
    let $maxDate := teis:normalize-date(request:get-parameter("date-max", ()), true())
    return
        if (exists($minDate) and exists($maxDate)) then
            filter($result, function($item) {
                ft:field($item, "date-min", "xs:date") >= $minDate
                and
                ft:field($item, "date-min", "xs:date") <= $maxDate
            })
        else if (exists($minDate)) then
            filter($result, function($item) {
                ft:field($item, "date-min", "xs:date") >= $minDate
            })
        else
            $result
};

declare function teis:normalize-date($date as xs:string?, $max) {
    if (exists($date) and $date != '') then
        let $tokens := tokenize($date, '-')
        return
            if (count($tokens) = 1) then
                xs:date(format-integer(xs:int($tokens), "0000") || (if ($max) then "-12-31" else "-01-01"))
            else if (count($tokens) = 2) then
                let $reformatted :=
                    format-integer(xs:int($tokens[1]), "0000") || "-" ||
                    format-integer(xs:int($tokens[2]), "00") || 
                    "-01"
                return
                    if ($max) then
                        xs:date($reformatted) + xs:yearMonthDuration("P1M")
                    else
                        xs:date($reformatted)
            else
                xs:date(
                    format-integer(xs:int($tokens[1]), "0000") || "-" ||
                    format-integer(xs:int($tokens[2]), "00") || "-" ||
                    format-integer(xs:int($tokens[3]), "00")
                )
    else
        ()
};

declare function teis:autocomplete($doc as xs:string?, $fields as xs:string+, $q as xs:string) {
    let $lower-case-q := lower-case($q)
    for $field in $fields
    return
        switch ($field)
            case "author" return
                collection($config:data-root)/ft:index-keys-for-field("author", $lower-case-q,
                    function($key, $count) {
                        $key
                    }, 30)
            case "file" return
                collection($config:data-root)/ft:index-keys-for-field("file", $lower-case-q,
                    function($key, $count) {
                        $key
                    }, 30)
            case "text" return
                if ($doc) then (
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:div"), $lower-case-q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index"),
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:TEI"), $lower-case-q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index")
                ) else (
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:div"), $lower-case-q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index"),
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:TEI"), $lower-case-q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index")
                )
            case "head" return
                if ($doc) then
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:head"), $lower-case-q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index")
                else
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:head"), $lower-case-q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index")
            default return
                collection($config:data-root)/ft:index-keys-for-field("title", $lower-case-q,
                    function($key, $count) {
                        $key
                    }, 30)
};

declare function teis:get-parent-section($node as node()) {
    ($node/self::tei:text, $node/ancestor-or-self::tei:div[1], $node)[1]
};

declare function teis:get-breadcrumbs($config as map(*), $hit as node(), $parent-id as xs:string) {
    let $work := root($hit)/*
    let $work-title := nav:get-document-title($config, $work)/string()
    return
        <div class="breadcrumbs">
            <a class="breadcrumb" href="{$parent-id}">{$work-title}</a>
            {
                for $parentDiv in $hit/ancestor-or-self::tei:div[tei:head]
                let $id := util:node-id(
                    if ($config?view = "page") then ($parentDiv/preceding::tei:pb[1], $parentDiv)[1] else $parentDiv
                )
                return
                    <a class="breadcrumb" href="{$parent-id || "?action=search&amp;root=" || $id || "&amp;view=" || $config?view || "&amp;odd=" || $config?odd}">
                    {$parentDiv/tei:head/string()}
                    </a>
            }
        </div>
};

(:~
 : Expand the given element and highlight query matches by re-running the query
 : on it.
 :)
declare function teis:expand($data as node()) {
    let $query := session:get-attribute($config:session-prefix || ".search")
    let $field := session:get-attribute($config:session-prefix || ".field")
    let $result := teis:query-default-view($data, $query, $field)
    let $expanded :=
        if (exists($result)) then
            util:expand($result, "add-exist-id=all")
        else
            $data
    return
        $expanded
};


declare %private function teis:query-default-view($context as node()*, $query as xs:string, $fields as xs:string*) {
    $context[./descendant-or-self::tei:TEI[ft:query(., $query, $query:QUERY_OPTIONS)]]
};

declare function teis:get-current($config as map(*), $div as node()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
            $div
        else
            (nav:filler($config, $div), $div)[1]
};
