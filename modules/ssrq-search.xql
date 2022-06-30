xquery version "3.1";

module namespace query="http://existsolutions.com/ssrq/search";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace http="http://expath.org/ns/http-client";
import module namespace browse="http://www.tei-c.org/tei-simple/templates" at "lib/browse.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "navigation.xql";
import module namespace app="http://existsolutions.com/ssrq/app" at "app.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace common="http://www.tei-c.org/tei-simple/xquery/functions/ssrq-common" at "ext-common.xql";
import module namespace queryDef="http://www.tei-c.org/tei-simple/query" at "query.xql";

declare variable $query:QUERY_OPTIONS :=
    <options>
        <leading-wildcard>yes</leading-wildcard>
        <filter-rewrite>yes</filter-rewrite>
    </options>;

declare variable $query:DOCS := collection($config:data-root) except collection($config:temp-root);

(:~
 : Execute query. Dispatches the query to either query:query-texts or query:query-api depending on $type.
 :)
declare
    %templates:default("type", "text")
    %templates:default("subtype", "edition")
function query:query($node as node()*, $model as map(*), $type as xs:string, $subtype as xs:string*, $query as xs:string?, $doc as xs:string*,
    $sort as xs:string?, $refresh as xs:boolean?) as map(*) {          
    
    if (empty($refresh)) then
        let $sortOrder := session:get-attribute("ssrq.sort")
        return
            map {
                "hits" :
                    if (empty($sort) or $sortOrder = $sort) then
                        session:get-attribute("ssrq")
                    else (
                        query:sort(session:get-attribute("ssrq"), $sort),
                        session:set-attribute("ssrq.sort", $sort)
                ),
                "ids": session:get-attribute("ssrq.ids"),
                "hitCount" : session:get-attribute("ssrq.hitCount"),
                "query" : session:get-attribute("ssrq.query"),
                "docs": session:get-attribute("ssrq.docs")
            }
    else
        let $debug := util:log("info", "refresh is not empty, query: " || $query)
        let $debug := util:log("info", "sort: " || $sort)
        let $debug := util:log("info", "type: " || $type)
        let $hits :=
            if ($query) then
                switch ($type)
                    case "text" return
                        query:query-texts(tokenize($subtype, '\s*,\s*'), $query)
                    default return
                        query:query-api($type, $subtype, $query)
            else map {
                "hits": query:filter(collection($config:data-root)//tei:body[ft:query(., 'type:document', queryDef:options(()))])
            }
        let $debug := util:log("info", "hits: " || count($hits))
        let $hitCount := count($hits?hits)
        let $debug := util:log("info", "hitCount: " || count($hitCount))

        let $hitsToShow := query:sort($hits?hits, $sort)
        let $debug := util:log("info", "hitsToShow: " || count($hitsToShow))
        (:Store the result in the session.:)
        let $store := (
            session:set-attribute("ssrq", $hitsToShow),
            session:set-attribute($config:session-prefix || '.hits', $hitsToShow),
            session:set-attribute("ssrq.hitCount", $hitCount),
            session:set-attribute("ssrq.query", $query),
            session:set-attribute("ssrq.type", $type),
            session:set-attribute("ssrq.subtype", $subtype),
            session:set-attribute("ssrq.docs", $doc),
            session:set-attribute("ssrq.sort", $sort),
            request:get-parameter-names()[starts-with(., 'filter-')] ! session:set-attribute("ssrq." || ., request:get-parameter(., ()))
        )
        return
            (: The hits are not returned directly, but processed by the nested templates :)
            map {
                "hits" : $hitsToShow,
                "ids": $hits?id,
                "hitCount" : $hitCount,
                "query" : $query,
                "docs": $doc
            }
};

declare function query:form-current-doc($node as node(), $model as map(*), $doc as xs:string?) {
    <input type="hidden" name="doc" value="{$doc}"/>
};

(:~
 : Editionstext durchsuchen
 :)
declare function query:query-texts($subtypes as xs:string*, $query as xs:string) {
    let $hits :=
        (: Nur Dokumente: entfernt andere Überlieferungen, Literaturverzeichnis etc. :)
        let $query := "type:document AND " || $query
        let $log := util:log('INFO', ("query: " || $query || "; subtypes: ", $subtypes))
        for $subtype in $subtypes
        return
            switch ($subtype)
                case "title" return
                    $query:DOCS//tei:teiHeader//tei:msDesc/tei:head[ft:query(., $query, queryDef:options(()))]
                case "idno" return
                    $query:DOCS//tei:teiHeader//tei:msDesc/tei:msIdentifier/tei:idno[ft:query(., $query, queryDef:options(()))]
                case "regest" return
                    $query:DOCS//tei:teiHeader//tei:msContents/tei:summary[ft:query(., $query, queryDef:options(()))]
                case "comment" return
                    $query:DOCS//tei:back[ft:query(., $query, queryDef:options(()))]
                case "notes" return
                    $query:DOCS//tei:body//tei:note[ft:query(., $query, queryDef:options(()))] |
                    $query:DOCS//tei:back//tei:note[ft:query(., $query, queryDef:options(()))]
                case "seal" return
                    $query:DOCS//tei:teiHeader//tei:msDesc/tei:physDesc/tei:sealDesc/tei:seal[ft:query(., $query, queryDef:options(()))]
                (: Editionstext: body + orig in Kommentar und Fussnoten :)
                default return
                    $query:DOCS//tei:body[ft:query(., $query, queryDef:options(()))] |
                    $query:DOCS//tei:back[.//tei:orig[ft:query(., $query, queryDef:options(()))]] |
                    $query:DOCS//tei:body[.//tei:note//tei:orig[ft:query(., $query, queryDef:options(()))]]
    let $debug := util:log("info", "query:query-texts: $hits: " || count($hits))                    

    return
        map {
            "hits":
                for $hit in query:filter($hits)
                order by ft:score($hit) descending
                return $hit
        }
};

(:~
 : Sachregister durchsuchen über externe API
 :)
declare function query:query-api($type as xs:string, $subtypes as xs:string*, $query as xs:string) as map(*) {
    let $url :=
        switch ($type)
            case "places" return
                "https://www.ssrq-sds-fds.ch/places-db-edit/views/loc-search.xq?query="
            case "lemma" return
                "https://www.ssrq-sds-fds.ch/lemma-db-edit/views/lem-search.xq?query="
            case "person" return
                "https://www.ssrq-sds-fds.ch/persons-db-api/?per_search="
            case "organisation" return
                "https://www.ssrq-sds-fds.ch/persons-db-api/?org_search="
            default return
                "https://www.ssrq-sds-fds.ch/lemma-db-edit/views/key-search.xq?query="
    let $log := util:log("info", "Request: " || $url || encode-for-uri($query))
    let $request :=
        <http:request method="GET" href="{$url}{encode-for-uri($query)}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = "200") then
            let $json := parse-json(util:binary-to-string(xs:base64Binary($response[2])))
            let $ids :=
                if ($json?results instance of map()) then
                    $json?results?id
                else
                    for-each($json?results?*, function($result) {
                        $result?id
                    })
            (: let $log := util:log("info", "IDs: " || string-join($ids, ', ')) :)
            return
                map {
                    "id": $ids,
                    "hits":
                        query:filter(
                            query:api-filter-subtype($ids, $type, $subtypes)
                        )
                }
        else
            util:log("info", serialize($response[1]))
};

(:~
 : Filter api search result depending on subtype. All filters are applied in sequence.
 :)
declare function query:api-filter-subtype($id as xs:string*, $type as xs:string, $subtypes as xs:string*) {
    if ($type = "keywords") then
        $query:DOCS/tei:TEI[tei:teiHeader/tei:profileDesc/tei:textClass/tei:keywords/tei:term/@ref = $id]/tei:text |
        $query:DOCS/tei:TEI/tei:text[descendant::tei:term/@ref = $id]
    else
        for $subtype in $subtypes
        return
            switch ($subtype)
                case "title" return
                    $query:DOCS//tei:teiHeader//tei:msDesc/tei:head/
                        (descendant::tei:placeName|descendant::tei:term|descendant::tei:persName|descendant::tei:orgName)[substring(@ref, 1, 9) = $id]
                case "regest" return
                    $query:DOCS//tei:teiHeader//tei:msDesc/tei:msContents/tei:summary/
                        (descendant::tei:placeName|descendant::tei:term|descendant::tei:persName|descendant::tei:orgName)[substring(@ref, 1, 9) = $id]
                case "comment" return
                    $query:DOCS//tei:back[
                        (descendant::tei:placeName|descendant::tei:term|descendant::tei:persName|descendant::tei:orgName)[substring(@ref, 1, 9) = $id]]
                case "notes" return
                    $query:DOCS/(descendant::tei:body|descendant::tei:back)//tei:note/
                        (descendant::tei:placeName|descendant::tei:term|descendant::tei:persName|descendant::tei:orgName)[substring(@ref, 1, 9) = $id]
                case "seal" return
                    $query:DOCS//tei:teiHeader//tei:msDesc/tei:physDesc/tei:sealDesc/tei:seal/tei:persName[substring(@ref, 1, 9) = $id]
                (: Editionstext: body + orig in Kommentar und Fussnoten :)
                default return
                    $query:DOCS//tei:body[
                        (descendant::tei:placeName|descendant::tei:term|descendant::tei:persName|descendant::tei:orgName)[substring(@ref, 1, 9) = $id]] |
                    $query:DOCS//tei:back[.//tei:orig/
                        (descendant::tei:placeName|descendant::tei:term|descendant::tei:persName|descendant::tei:orgName)[substring(@ref, 1, 9) = $id]] |
                    $query:DOCS//tei:body[.//tei:note//tei:orig/
                        (descendant::tei:placeName|descendant::tei:term|descendant::tei:persName|descendant::tei:orgName)[substring(@ref, 1, 9) = $id]] |
                    $query:DOCS//tei:body[.//@scribe = $id]
};

(:~
 : Apply filters to the query result.
 :)
declare function query:filter($hits as element()*) {
    let $debug:= util:log("info", "query:filter hits: " || count($hits))
    (: let $debug:= util:log("warn", serialize($hits)) :)
    
    return
        fold-right(request:get-parameter-names()[starts-with(., 'filter-')], $hits, function($filter, $context) {
            let $value := filter(request:get-parameter($filter, ()), function($param) { $param != "" })
            return
                if (exists($value) and $value != '') then
                    switch ($filter)
                        case "filter-period-min" return
                            let $dateMin := xs:date($value || "-01-01")
                            for $c in $context
                            where try { $c/ancestor-or-self::tei:TEI//tei:history/tei:origin/tei:origDate[@when >= $dateMin] } catch * {()}
                            return
                                $c
                        case "filter-period-max" return
                            let $dateMax := xs:date($value || "-12-31")
                            for $c in $context
                            where try { $c/ancestor-or-self::tei:TEI//tei:history/tei:origin/tei:origDate[@when <= $dateMax] } catch * {()}
                            return
                                $c
                        case "filter-language" return
                            $context[ancestor-or-self::tei:TEI//tei:textLang = tokenize($value, "\s*,\s*")]
                        case "filter-condition" return
                            if ($value = "yes") then
                                $context[ancestor-or-self::tei:TEI//tei:supportDesc/tei:condition]
                            else
                                $context[not(ancestor-or-self::tei:TEI//tei:supportDesc/tei:condition)]
                        case "filter-material" return
                            $context[ancestor-or-self::tei:TEI//tei:support/tei:material = $value]
                        case "filter-seal" return
                            if ($value = "yes") then
                                $context[ancestor-or-self::tei:TEI//tei:sealDesc/tei:seal]
                            else
                                $context[not(ancestor-or-self::tei:TEI//tei:sealDesc/tei:seal)]
                        case "filter-author" return
                            if ($value = "yes") then
                                $context[ancestor-or-self::tei:TEI//tei:msContents/tei:msItem/tei:author/@role = 'scribe']
                            else
                                $context[not(ancestor-or-self::tei:TEI//tei:msContents/tei:msItem/tei:author/@role = 'scribe')]
                        case "filter-kanton" return
                            for $v in $value
                            return
                                $context[ancestor-or-self::tei:TEI[matches(tei:teiHeader//tei:seriesStmt/tei:idno, ``[^(?:SSRQ|SDS|FDS)_`{$v}`.*$]``)]]
                        case "filter-pubdate-min" return
                            let $dateMin := xs:date($value || "-01-01")
                            return
                                $context[ancestor-or-self::tei:TEI//tei:publicationStmt/tei:date[@type='electronic']/@when >= $dateMin]
                        case "filter-pubdate-max" return
                            let $dateMax := xs:date($value || "-12-31")
                            return
                                $context[ancestor-or-self::tei:TEI//tei:publicationStmt/tei:date[@type='electronic'][@when <= $dateMax]]
                        case "filter-pubplace" return
                            if ($value = "yes") then
                                $context[ancestor-or-self::tei:TEI//tei:history/tei:origin/tei:origPlace]
                            else
                                $context[not(ancestor-or-self::tei:TEI//tei:history/tei:origin/tei:origPlace)]
                        case "filter-archive" return
                            $context[starts-with(ancestor-or-self::tei:TEI//tei:teiHeader//tei:msDesc/tei:msIdentifier/tei:idno, $value)]
                        case "filter-filiation" return
                            for $node in $context
                            let $idno := $node/ancestor-or-self::tei:TEI//tei:teiHeader//tei:msDesc/tei:msIdentifier/tei:idno
                            let $filiations :=
                                collection($config:data-root)//tei:idno[. = $idno]/ancestor::tei:teiHeader//tei:filiation
                            let $log := util:log("info", ($idno, count($filiations)))
                            return
                                if ($value = "yes" and exists($filiations)) then
                                    $node
                                else if ($value = "no" and empty($filiations)) then
                                    $node
                                else if ($value  and count($filiations[contains(., $value)])) then
                                    $node
                                else
                                    ()
                        default return
                            $context
                else
                    $context
        })
};

(:~
 : Highlight matches when viewing document after search.
 :)
declare function query:highlight($action as xs:string?, $context as element()*, $subtype as xs:string?, $sr as xs:string*) {
    if ($action = "search") then
        let $query := session:get-attribute("ssrq.query")
        let $type := session:get-attribute("ssrq.type")
        let $subtypes := session:get-attribute("ssrq.subtype")
        let $subtype :=
            if ($subtype) then
                if (index-of($subtypes, $subtype)) then
                    $subtype
                else
                    ()
            else
                $subtypes
        return
            if (exists($subtype)) then
                switch ($type)
                    case "text" return
                        util:expand(query:highlight-texts($context, $subtype, $query), "add-exist-id=all")
                    default return
                        let $highlighted := query:highlight-annotations($context, $sr)
                        return
                            $highlighted
            else
                $context
    else
        $context
};

(:~
 : Highlight fulltext matches
 :)
declare function query:highlight-texts($context as element()*, $subtypes as xs:string*, $query as xs:string) {
    for $subtype in $subtypes
    return
        switch ($subtype)
            case "title" case "idno"
            case "regest" case "comment"
            case "seal" return
                $context | $context[ft:query(., $query, $query:QUERY_OPTIONS)]
            case "notes" return
                $context |
                $context[./descendant-or-self::tei:body//tei:note[ft:query(., $query, $query:QUERY_OPTIONS)]] |
                $context[./descendant-or-self::tei:back//tei:note[ft:query(., $query, $query:QUERY_OPTIONS)]]
            (: Editionstext: body + orig in Kommentar und Fussnoten :)
            case "edition" return
                $context |
                $context[./descendant-or-self::tei:body[ft:query(., $query, $query:QUERY_OPTIONS)]]/ancestor::tei:TEI |
                $context[./descendant-or-self::tei:back//tei:orig[ft:query(., $query, $query:QUERY_OPTIONS)]] |
                $context[./descendant-or-self::tei:body//tei:note//tei:orig[ft:query(., $query, $query:QUERY_OPTIONS)]]
            default return
                ()
};

(:~
 : Highlight places, persons, terms ...
 :)
declare function query:highlight-annotations($nodes as node()*, $ids as xs:string*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(tei:persName) | element(tei:placeName) | element(tei:orgName) | element(tei:term) return
                element { node-name($node) } {
                    $node/@*,
                    if (substring($node/@ref, 1, 9) = $ids) then
                        <exist:match exist:id="{util:node-id($node)}">{ query:highlight-annotations($node/node(), $ids) }</exist:match>
                    else
                        query:highlight-annotations($node/node(), $ids)
                }
            case element(tei:ab) | element(tei:add) | element(tei:addSpan) | element(tei:handShift) return
                element { node-name($node) } {
                    $node/@*,
                    if ($node/@scribe = $ids) then
                        <exist:match exist:id="{util:node-id($node)}">{ query:highlight-annotations($node/node(), $ids) }</exist:match>
                    else
                        query:highlight-annotations($node/node(), $ids)
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    query:highlight-annotations($node/node(), $ids)
                }
            default return $node
};

(:~
    Display an info text in case there are no search results, otherwise, the results pane will be rendered empty
:)
declare
    %templates:replace
function query:show-no-results-info($node as node()*, $model as map(*)) {
    let $result := count($model?hits)
    let $success := $result > 0
    return
        if ($success)
        then ()
        else (
            <p><pb-i18n key="no-search-results">Ihre Suche erzielte keinen Treffer.</pb-i18n></p>
        )
};

(:~
    Output the actual search result as a div, using the kwic module to summarize full text matches.
:)
declare
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function query:show-hits($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer, $view as xs:string?, $lang as xs:string?) {
    response:set-header("pb-total", xs:string(count($model?hits))),
    response:set-header("pb-start", xs:string($start)),
    for $hit at $p in subsequence($model("hits"), $start, $per-page)    
    let $parent := ($hit/self::tei:body, $hit/ancestor-or-self::tei:div[1])[1]
    let $parent := ($parent, $hit/ancestor-or-self::tei:teiHeader, $hit)[1]
    let $parent-id := config:get-identifier($parent)
    let $parent-id :=
        if ($model?docs) then replace($parent-id, "^.*?([^/]*)$", "$1") else $parent-id
    let $work := $hit/ancestor::tei:TEI
    let $config := tpu:parse-pi(root($work), $view)
    let $div := query:get-current($config, $parent)

    let $expanded :=
        if (exists($model?ids)) then
            (: Suche in Sachregister, $hit ist placeName :)
            query:expand($parent, $model?ids)
        else
            util:expand($hit, "add-exist-id=all")
    let $docId := config:get-identifier($div)
    let $docId :=
        if ($model?docs) then
            replace($docId, "^.*?([^/]*)$", "$1")
        else
            $docId            
    let $category := query:category($hit)
    return (
      <paper-card class="reference">
        <header>
            <div class="item" xmlns:i18n="http://exist-db.org/xquery/i18n">
                <h5><span class="badge"><pb-i18n key="{$category}"/></span> –
                    <span>{query:view-idno($work)}</span> –
                    <span>{query:view-origDate($work)}</span>
                </h5>
                <h4>{query:view-header($work, $parent-id)}</h4>
            </div>  
        </header>
        <div class="matches">
            {              
              for $match in subsequence($expanded//exist:match, 1, 5)
              let $matchId := $match/../@exist:id
              let $docLink :=
                  if ($hit/ancestor-or-self::tei:back) then
                      ()
                  else if ($config?view = "page") then
                      let $contextNode := util:node-by-id($div, $matchId)
                      let $page := $contextNode/preceding::tei:pb[1]
                      return
                          util:node-id($page)
                  else
                      util:node-id($div)
              let $action := if (exists($model?ids)) then "" else "search"
              let $config :=
                  if (exists($model?ids)) then
                      let $idList := string-join(for $id in $model?ids return "sr=" || $id, "&amp;")
                      return
                          <config width="60" table="no"
                              link="{$docId}?view={$config?view}&amp;action=search&amp;odd={$config?odd}&amp;{$idList}#{$matchId}"/>
                  else
                      <config width="60" table="no"
                          link="{$docId}?root={$docLink}&amp;action=search&amp;view={$config?view}&amp;odd={$config?odd}#{$matchId}"/>
              return
                  kwic:get-summary($expanded, $match, $config)
            }
      </div>
    </paper-card>

    )
};

declare function query:category($hit as element()) {
    typeswitch($hit)
        case element(tei:head) return "title"
        case element(tei:idno) return "idno"
        case element(tei:summary) return "regest"
        case element(tei:note) return "notes"
        case element(tei:back) return "comment"
        case element(tei:seal) return "seal"
        default return "editiontext"
};

declare function query:sort($items as element()*, $sortBy as xs:string?) {
    let $debug := util:log("info", "query:sort sortBy: " || $sortBy || " - items: " || count($items))

    return
    switch($sortBy)
        case "kanton" return
            for $item in $items
            order by
                replace(root($item)//tei:teiHeader//tei:seriesStmt/tei:idno, "^(?:SSRQ|SDS|FDS)_([^_]+).*$", "$1"),
                try {
                    xs:date(root($item)//tei:teiHeader/tei:fileDesc//tei:msDesc/tei:history/tei:origin/tei:origDate/(@when|@from))
                } catch * {
                    ()
                }
            return
                $item
        case "title" return
            for $item in $items
            let $header := root($item)//tei:teiHeader
            order by
                ($header//tei:msDesc/tei:head/string(), $header//tei:titleStmt/tei:title/string())[1]
            return
                $item
        case "id" return
            for $item in $items
            order by root($item)//tei:teiHeader/tei:fileDesc/tei:seriesStmt/tei:idno
            return
                $item                
        case "relevance" return
            for $item in $items
            order by ft:score($item)
            return
                $item
        default return
            (: sort($items, (), ft:field(?, "idno")) :)
            for $item in $items
            let $date := ft:field($item, 'date-min', 'xs:date')
            (: order by root($item)//tei:teiHeader/tei:fileDesc/tei:seriesStmt/tei:idno :)
            order by $date
            return            
                $item
};

declare function query:view-header($work as element(), $parent-id as xs:string) {
    let $header := $work//tei:teiHeader
    let $head := ($header//tei:msDesc/tei:head/node(), $header//tei:titleStmt/tei:title/node())[1]
    return
        <a href="{$parent-id}">{$pm-config:web-transform($head, map { "root": $head }, $config:odd)}</a>
};

declare function query:view-kanton($work as element()) {
    replace($work//tei:teiHeader//tei:seriesStmt/tei:idno, "^(?:SSRQ|SDS|FDS)_([^_]+).*$", "$1")
};

declare function query:view-idno($work as element()) {
    let $header := $work//tei:teiHeader
    let $idno := $header/tei:fileDesc/tei:seriesStmt/tei:idno
    return
        common:format-id($idno)
};

declare function query:view-origDate($work as element()) {
    let $origDate := $work//tei:teiHeader/tei:fileDesc//tei:msDesc/tei:history//tei:origDate
    return
        if ($origDate/@when) then
            try {
                format-date(xs:date($origDate/@when), '[Y] [MNn] [D01]', (session:get-attribute("ssrq.lang"), "de")[1], (), ())
            } catch * {
                $origDate/@when/string()
            }
        else
            try {
                format-date(xs:date($origDate/@from), '[Y] [MNn] [D01]', (session:get-attribute("ssrq.lang"), "de")[1], (), ()) ||
                ' - ' ||
                format-date(xs:date($origDate/@to), '[Y] [MNn] [D01]', (session:get-attribute("ssrq.lang"), "de")[1], (), ())
            } catch * {
                $origDate/@from || " - " || $origDate/@to
            }
};

(:~
 : Wrap terms, places or persons found via external API search into an exist:match so they are shown
 : in the kwic display.
 :)
declare function query:expand($nodes as node()*, $ids as xs:string+) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(tei:term) | element(tei:placeName) | element(tei:persName) | element(tei:orgName) return
                element { node-name($node) } {
                    $node/@*,
                    if (substring($node/@ref, 1, 9) = $ids) then (
                        attribute exist:id { util:node-id($node) },
                        <exist:match>{ query:expand($node/node(), $ids) }</exist:match>
                    ) else
                        query:expand($node/node(), $ids)
                }
            case element(tei:ab) | element(tei:add) | element(tei:addSpan) | element(tei:handShift) return
                element { node-name($node) } {
                    $node/@*,
                    if ($node/@scribe = $ids) then (
                        attribute exist:id { util:node-id($node) },
                        <exist:match>{ query:expand($node/node(), $ids) }</exist:match>
                    ) else
                        query:expand($node/node(), $ids)
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    query:expand($node/node(), $ids)
                }
            default return $node
};


declare %private function query:get-current($config as map(*), $div as element()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
            $div
        else
            if (
                empty($div/preceding-sibling::tei:div)  (: first div in section :)
                and count($div/preceding-sibling::*) < 5 (: less than 5 elements before div :)
                and $div/.. instance of element(tei:div) (: parent is a div :)
            ) then
                nav:get-previous($config, $div/..,$config:default-view)
            else
                $div
};

declare %templates:wrap
function query:period-range($node as node(), $model as map(*)) {
    let $context :=
        if ($model?hits) then
            $model?hits ! root(.)
        else
            collection($config:data-root)
    let $dates :=
        for $when in $context//tei:teiHeader//tei:history/tei:origin/tei:origDate/@when
        return
            try {
                year-from-date(xs:date($when))
            } catch * {
                util:log("warn", "Invalid date: " || document-uri(root($when)))
            }
    return
        map {
            "min": min($dates),
            "max": max($dates)
        }
};

declare
    %templates:wrap
function query:pubdate-range($node as node(), $model as map(*)) {
    let $context :=
        if ($model?hits) then
            $model?hits ! root(.)
        else
            collection($config:data-root)
    let $dates :=
        for $when in $context//tei:teiHeader//tei:publicationStmt/tei:date[@type='electronic']/@when
        return
            try {
                year-from-date(xs:date($when))
            } catch * {
                if (matches($when, "^\d+$")) then
                    xs:integer($when)
                else
                    ()
            }
    return
        map {
            "min": min($dates),
            "max": max($dates)
        }
};
declare
    %templates:replace
function query:list-archives($node as node(), $model as map(*), $filter-archive as xs:string?) {
    $node/*,
    let $context :=
        if ($model?hits) then
            $model?hits ! root(.)
        else
            collection($config:data-root)
    let $items := for $idno in distinct-values(
                    for-each($context//tei:teiHeader//tei:msDesc/tei:msIdentifier/tei:idno, function($id) {
                        replace($id, "^\s*(\w+).*$", "$1")
                    })
            )            
            order by $idno
            return 
                <paper-item value="{$idno}">
                {
                    if ($idno = $filter-archive) then
                        attribute selected { "selected" }
                    else
                        ()
                }
                {$idno}
                </paper-item>
    return
        ( $items)

};

declare
    %templates:wrap
function query:set-default-params($node as node(), $model as map(*)) {
    let $new-model := map:merge(($model, 
                                map { "type": "text" },
                                map { "sort": "date" },
                                map { "subtype": "edition" }
                            ))    
    return
        templates:process($node/*, $new-model)
};