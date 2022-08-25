xquery version "3.1";

module namespace app="http://existsolutions.com/ssrq/app";

import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace common="http://www.tei-c.org/tei-simple/xquery/functions/ssrq-common" at "ext-common.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei" at "navigation-tei.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.expath.exist.HttpClientModule";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace expath="http://expath.org/ns/pkg";

declare variable $app:TEMP_DOCS := collection($config:temp-root)/tei:TEI;
declare variable $app:ALL_DOCS := collection($config:data-root);

declare variable $app:HOST := "https://www.ssrq-sds-fds.ch";

declare variable $app:PLACES := $app:HOST || "/places-db-edit/views/get-infos.xq";
declare variable $app:PERSONS := $app:HOST || "/persons-db-api/";
declare variable $app:LEMMA := $app:HOST || "/lemma-db-edit/views/get-lem-infos.xq";
declare variable $app:KEYWORDS := $app:HOST || "/lemma-db-edit/views/get-key-infos.xq";
declare variable $app:LITERATUR := doc('../data/SSRQ_ZH_NF_Bibliographie_integral.xml');

declare %templates:replace
    function app:show-if-logged-in($node as node(), $model as map(*)) {
        let $user := request:get-attribute($config:login-domain || ".user")
        return
            if ($user) then
                element { node-name($node) } {
                    $node/@*,
                    templates:process($node/*[1], $model)
                }
            else
                ()            
};

declare %templates:replace
    function app:show-if-not-logged-in($node as node(), $model as map(*)) {
        let $user := request:get-attribute($config:login-domain || ".user")
        return
            if (not($user)) then
                element { node-name($node) } {
                    $node/@*,
                    templates:process($node/*[1], $model)
                }
            else
                ()            
};

declare
    %templates:wrap
function app:download-pdf($node as node(), $model as map(*)) {
    let $resource := replace($model?doc, '^([A-Z]{2})/(.+?)/(.+?)(?:_\d{1,2})?\.xml$', '$1/$2/pdf/$3.pdf')
    return
        <a href="{request:get-context-path()}/apps/rqzh-data/data/{$resource}">
        {
            $node/@*,
            templates:process($node/node(), $model)
        }
        </a>
};
declare
    %templates:wrap
function app:download-xml($node as node(), $model as map(*)) {
    <a href="{request:get-context-path()}/apps/rqzh-data/{$model?doc}">
    {
        $node/@*,
        templates:process($node/node(), $model)
    }
    </a>
};

(:~
 :
 :)
declare
    %templates:wrap
function app:kanton-auswahl($node as node(), $model as map(*)) {
    let $kanton := app:select-kanton()
    for $tr in $node/tr
    let $class := if ($tr/td[2]/string() = $kanton) then 'active' else ()
    return
        <tr class="{$class}">
            { templates:process(subsequence($tr/td, 1, 2), $model) }
            <td>
            {
                let $current := $tr/td[2]
                let $docs := 
                    $app:ALL_DOCS/tei:TEI[ft:query(., 'kanton:' || $current, query:options(()))][.//tei:text/tei:body/*]
                        except
                    $app:TEMP_DOCS
                let $docs := nav:filter-collections($docs)
                return (
                    $tr/td[3]/@*,
                    if (exists($docs)) then
                        <span>
                            <a href="#" data-collection="{$current}">{$tr/td[3]/node()} </a>
                            <span class="badge">{count($docs)}</span>
                        </span>
                    else
                        $tr/td[3]/node()
                )
            }
            </td>
        </tr>
};

declare function app:select-kanton() {
    let $first := fold-left(("ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG", "FR", "SO", "BS", "BL", "SH", "AR", "AI", "SG",
        "GR", "AG", "TG", "TI", "VD", "VS", "NE", "GE", "JU"), (), function($zero, $kanton) {
            if ($zero) then
                $zero
            else if (exists(
                $app:ALL_DOCS/tei:TEI[ft:query(., 'kanton:' || $kanton)]
                    except
                $app:TEMP_DOCS
            )) then
                $kanton
            else
                $zero
        })
    return
        $first
};

declare function app:list-volumes($node as node(), $model as map(*), $root as xs:string?) {
    let $kanton := replace($model?root, "^/?(.*)$", "$1")
    for $volume in collection($config:data-root)/tei:TEI[@type='volinfo'][matches(.//tei:seriesStmt/tei:idno[@type="machine"], '^\w+_' || $kanton)]
    let $order := $volume/@n
    let $count := count($model?all intersect collection(util:collection-name($volume))//tei:TEI[ft:query(., 'type:document')])
    order by $order
    return
        if ($count > 0) then
            <div class="volume">
                <a href="#" data-collection="{substring-after(util:collection-name($volume), $config:data-root || "/")}">{ 
                    $pm-config:web-transform($volume/tei:teiHeader/tei:fileDesc, map { "root": $volume, "count": $count, "view": "volumes" }, $config:odd)
                }</a>
                {
                    session:set-attribute("ssrq.kanton", $kanton)
                }
            </div>
        else
            ()
};

declare function app:api-lookup($api as xs:string, $list as map(*)*, $param as xs:string) {
    let $lang := (session:get-attribute("ssrq.lang"), "de")[1]
    let $iso-639-3 :=
    map {
        'de'     : 'deu',
        'fr'     : 'fra',
        'it'     : 'ita',
        'en'     : 'eng'
    }
    let $refs := string-join(for $item in $list return $item?ref, ",")
    let $request := <http:request method="GET" href="{$api}?{$param}={$refs}&amp;lang={$iso-639-3($lang)}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = "200") then
            let $json := parse-json(util:binary-to-string($response[2]))
            return
                $json?info
        else
            ()
};

declare function app:api-lookup-xml($api as xs:string, $list as map(*)*, $param as xs:string) {
    let $lang := (session:get-attribute("ssrq.lang"), "de")[1]
    let $iso-639-3 :=
    map {
        'de'     : 'deu',
        'fr'     : 'fra',
        'it'     : 'ita',
        'en'     : 'eng'
    }
    let $refs := string-join(for $item in $list return $item?ref, ",")
    let $request := <http:request method="GET" href="{$api}?{$param}={$refs}&amp;lang={$iso-639-3($lang)}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = "200") then
            $response[2]
        else
            ()
};

declare function app:api-keys($refs as xs:string*) {
    for $id in $refs
    group by $ref := substring($id, 1, 9)
    (: group by $ref := replace($id, "^([^\.]+).*$", "$1") :)
    return
        map {
            "ref": $ref,
            "name": $id[1]
        }
};

declare function app:list-places($node as node(), $model as map(*)) {
    let $places := root($model?data)//(tei:placeName[@ref]|tei:origPlace[@ref])
    where exists($places)
    return map {
        "items":
            for $place in app:api-lookup-xml($app:PLACES, app:api-keys($places/@ref), "id")//info
            order by $place/stdName
            return
                <li data-ref="{$place/@id}">
                    <paper-checkbox class="select-facet" title="i18n(highlight-facet)"></paper-checkbox>
                    <div>
                        <a target="_new"
                            href="https://www.ssrq-sds-fds.ch/places-db-edit/views/view-place.xq?id={$place/@id}">
                            {$place/stdName/string()}
                        </a>
                        ({$place/location/string()})
                        {$place/type/string()}
                    </div>
                </li>
    }
};

declare function app:list-keys($node as node(), $model as map(*)) {
    let $keywords := root($model?data)//tei:term[starts-with(@ref, 'key')]
    where exists($keywords)
    return map {
        "items":
            for $lemma in app:api-lookup-xml($app:KEYWORDS, app:api-keys($keywords/@ref), "id")//info
            order by $lemma/name
            return
                <li data-ref="{$lemma/@id}">
                    <paper-checkbox class="select-facet" title="i18n(highlight-facet)"></paper-checkbox>
                    <div>
                        <a href="https://www.ssrq-sds-fds.ch/lemma-db-edit/views/view-keyword.xq?id={$lemma/@id}"
                            target="_new">
                            {$lemma/name/string()}
                        </a>
                    </div>
                </li>
    }
};

declare function app:list-lemmata($node as node(), $model as map(*)) {
    let $lemmata := root($model?data)//tei:term[starts-with(@ref, 'lem')]
    where exists($lemmata)
    return map {
        "items":
            for $lemma in app:api-lookup-xml($app:LEMMA, app:api-keys($lemmata/@ref), "id")//info
            order by $lemma/stdName
            return
                <li data-ref="{$lemma/@id}">
                    <paper-checkbox class="select-facet" title="i18n(highlight-facet)"></paper-checkbox>
                    <div>
                        <a target="_new"
                            href="https://www.ssrq-sds-fds.ch/lemma-db-edit/views/view-lemma.xq?id={$lemma/@id}">
                            {$lemma/stdName/string()}
                        </a>
                        ({$lemma/morphology/string()})
                        {$lemma/definition/string()}
                    </div>
                </li>
    }
};

declare function app:list-persons($node as node(), $model as map(*)) {
    let $persons :=
        root($model?data)//tei:persName[@type="full_sorted"]/@ref |
        root($model?data)//@scribe[starts-with(., 'per')]
    where exists($persons)
    return map {
        "items":
            for $person in app:api-lookup($app:PERSONS, app:api-keys($persons), "ids_search")?*
            order by $person?name
            return
                <li data-ref="{$person?id}">
                    <paper-checkbox class="select-facet" title="i18n(highlight-facet)"></paper-checkbox>
                    <div>
                        <a target="_new"
                            href="https://www.ssrq-sds-fds.ch/persons-db-edit/?query={$person?id}">
                            {$person?name}
                        </a>
                        {
                            if ($person?dates) then
                                <span class="info"> ({$person?dates})</span>
                            else
                                ()
                        }
                    </div>
                </li>
    }
};

declare function app:list-organizations($node as node(), $model as map(*)) {
    let $organizations := root($model?data)//tei:orgName/@ref
    where exists($organizations)
    return map {
        "items":
            for $organization in app:api-lookup($app:PERSONS, app:api-keys($organizations), "ids_search")?*
            order by $organization?name
            return
                <li data-ref="{$organization?id}">
                    <paper-checkbox class="select-facet" title="i18n(highlight-facet)"></paper-checkbox>
                    <div>
                        <a target="_new"
                            href="https://www.ssrq-sds-fds.ch/persons-db-edit/?query={$organization?id}">
                            {$organization?name}
                        </a>
                        {
                            if ($organization?type) then
                                <span class="info"> ({$organization?type})</span>
                            else
                                ()
                        }
                    </div>
                </li>
    }
};

declare
    %templates:wrap
function app:show-list-items($node as node(), $model as map(*)) {
    for $item in $model?items
    order by $item/a collation "?lang=de_CH"
    return
        $item
};

declare function app:meta($node as node(), $model as map(*)) {
    let $data := config:get-document($model?doc)
    let $site := config:expath-descriptor()/expath:title/string()
    let $title := $data//tei:sourceDesc/tei:msDesc/tei:head => normalize-space()
    let $description := $data//tei:sourceDesc/tei:msDesc/tei:msContents/tei:summary => normalize-space()
    return
        map {
            "title": string-join(($site, $title), ': '),
            "description": $description,
            "language": "de",
            "url": "https://rechtsquellen.sources-online.org/" || $model?doc,
            "site": $site
        }
};

declare 
    %templates:wrap
function app:meta-title($node as node(), $model as map(*)) {
    $model?title
};

(:~
 : Display a facsimile thumbnail in the collection list next to each document, if available,
 : and link it to the document
 :)
declare
    %templates:replace
function app:short-header-link($node as node(), $model as map(*)) {
    let $work := root($model("work"))/*
    let $href := config:get-identifier($work)
    let $thumbnail-src := ($work//tei:body//tei:pb/@facs)[1]

    return (
        if (exists($thumbnail-src))
        then (
            element { node-name($node) } {
                $node/@*,
                attribute href { $href },
                element img {
                    attribute src { $config:iiif-base-uri || $thumbnail-src || '/full/178,/0/default.jpg'},
                    attribute class { 'document-thumbnail-image' },
                    templates:process($node/node(), $model)
                }
            }
        )
        else ()
    )
};

declare
    %templates:wrap    
    %templates:default("key","")
function app:load-person($node as node(), $model as map(*), $key as xs:string) {
    let $person := doc($config:data-root || "/person/person.xml")//tei:person[@xml:id = xmldb:decode($key)]
    let $log := util:log("info", "app:load-person $name: " || $person/tei:persName[@type="full"]/text() || " - $key:" || $key)
    
    return 
        map {
                "title": $person/tei:persName[@type="full"]/text(),
                "key":$key,
                "date":$person/tei:note[@type="date"]/text()
        }    
};

declare
    %templates:wrap    
    %templates:default("name","")
    %templates:default("key","")
function app:load-organization($node as node(), $model as map(*), $name as xs:string, $key as xs:string) {
    let $log := util:log("info", "app:load-organization $name: " || $name || " - $key:" || $key)
    let $org := doc($config:data-root || "/organization/organization.xml")//tei:org[@xml:id = xmldb:decode($key)]
    return 
        map {
                "title": $org/tei:orgName/text(),
                "key":$key,
                "type":$org/@type/string()
        }    
};



declare
    %templates:wrap    
    %templates:default("name","")
    %templates:default("key","")
function app:load-place($node as node(), $model as map(*), $name as xs:string, $key as xs:string) {
    let $log := util:log("info", "app:load-place $name: " || $name || " - $key:" || $key)
    let $place := doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place[@xml:id = xmldb:decode($key)]
    let $name := $place/tei:placeName[@type="main"]/string()
    let $type := substring-before($place/tei:trait[@type="type"][1]/tei:label/text(), "/")
    let $title := if(string-length($type) >0 ) then ( $name || " (" || $type || ")" ) else ($name)
    
(:    let $log := util:log("info", "app:load-place $title:" || $title):)
(:    let $log := util:log("info", "app:load-place $geo:" || $place//tei:geo/text()):)
    return 
        if(string-length(normalize-space($place//tei:geo/text())) > 1)
        then(
            let $geo-token := tokenize($place//tei:geo/text(), " ")
            return 
                map {
                    "title": $title,
                    "key":$key,
                    "latitude": $geo-token[1],
                    "longitude": $geo-token[2]
                }
        )
        else (
            map {
                "title": $title,
                "key":$key
            }    
        )
};
declare
    %templates:wrap    
    %templates:default("editionseinheit","")
function app:get-edition-unit($node as node(), $model as map(*), $editionseinheit as xs:string) {
    switch($editionseinheit) 
        case "ZH_NF_II_11" return   
            <pb-i18n key="menu.ZH_NF_II_11"/>
        case "ZH_NF_II_3" return 
            <pb-i18n key="menu.ZH_NF_II_3"/>
        case "ZH_NF_I_1_11" return 
            <pb-i18n key="menu.ZH_NF_I_1_11"/>
        case "ZH_NF_I_1_3" return 
            <pb-i18n key="menu.ZH_NF_I_1_3"/>
        case "ZH_NF_I_2_1" return 
            <pb-i18n key="menu.ZH_NF_I_2_1"/>
        default return 
            <pb-i18n key="menu.all"/>
};

declare 
    %templates:wrap  
    %templates:default("name", "")  
function app:show-map($node as node(), $model as map(*), $name as xs:string) {
    let $key := $model?key
    let $place :=  doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place[@xml:id = $key]
    return
        if(string-length(normalize-space($place//tei:geo/text() ) ) > 1)
        then (
            let $log := util:log("info", "show map" )
            return
                templates:process($node/*, $model)
        ) else (
            <ul>
                <li><pb-i18n key="missing-geo-data"/></li>
            </ul>
        ) 
};

declare %templates:default("name", "")  function app:person-name($node as node(), $model as map(*), $name as xs:string) {
    let $name := $model?title
    let $date := 
            if ( string-length( $model?date ) > 0 ) 
            then ( "(" || $model?date || ")" ) 
            else ()
    return
        $name || " " || $date
};
declare %templates:default("name", "")  function app:organization-name($node as node(), $model as map(*), $name as xs:string) {
    let $name := if($model?name) then ($model?name) else xmldb:decode($name)
    let $date := 
            if ( string-length( $model?type ) > 0 ) 
            then ( "(" || substring-before($model?type,"/") || ")" ) 
            else ()
    return
        $name || " " || $date
};



declare function app:person-link($node as node(), $model as map(*)) {
    let $key := $model?key
    let $name := $model?title
    return
        element a { 
            attribute href { "https://www.ssrq-sds-fds.ch/persons-db-edit/?query=" || $key },
            attribute target { "_blank"},
            <span>{xmldb:decode($name)} <pb-i18n key="at-ssrq-sds-fds"/></span>
        }    
};

declare %templates:default("name", "")  function app:place-link($node as node(), $model as map(*), $name as xs:string) {
    let $key := $model?key
    let $name := if($model?name) then ($model?name) else $name
    return
        element a {
            attribute href { "https://www.ssrq-sds-fds.ch/places-db-edit/views/view-place.xq?id=" || $key },
            attribute target { "_blank"},
            <span>{xmldb:decode($name)} <pb-i18n key="at-ssrq-sds-fds"/></span>
        }    
};

declare %templates:wrap 
        %templates:default("type", "place") 
function app:mentions($node as node(), $model as map(*), $type as xs:string) {
    let $key := $model?key
    let $log := util:log("info", "app:mentions: $key: " || $key )
    return
        if($type = "person") 
        then ( 
            let $person := doc($config:data-root || "/person/person.xml")//tei:person[@xml:id = $key]
            return
                <div>
                    <h3><pb-i18n key="mentions-of"/>{" " ||  $person/tei:persName[@type="full"]/text()}</h3>
                    <div class="mentions">{
                            for $col in $config:data-collections
                                let $matches := collection($config:data-root || "/" || $col)//tei:TEI[(.//tei:persName/@ref | @scribe) = $key]
                                let $log := util:log("info", "app:mentions: col: " || $col || " - $matches: " || count($matches))
                                return
                                    if(count($matches) > 0)
                                    then (
                                        <h4><pb-i18n key="menu.{$col}"/></h4>,
                                        <ul>{app:ref-list("place", $matches, $col, $key)}</ul>
                                    ) else()
                    }</div>
                </div>
        ) else if ($type = "place")
        then (
            let $places := doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place
            return
                <div>
                    <h3><pb-i18n key="mentions-of"/>{" " ||  $places[@xml:id = $key]/@n/string()}</h3>
                    <div class="mentions">{
                            for $col in $config:data-collections
                                let $matches := collection($config:data-root || "/" || $col)//tei:TEI[(.//tei:placeName/@ref|.//tei:origPlace/@ref) = $key]
                                let $log := util:log("info", "app:mentions: col: " || $col || " - $matches: " || count($matches))
                                return
                                    if(count($matches) > 0)
                                    then (
                                        <h4><pb-i18n key="menu.{$col}"/></h4>,
                                        <ul>{app:ref-list("place", $matches, $col, $key)}</ul>
                                    ) else()
                    }</div>
                </div>
        ) else if ($type = "organization")
        then (
            let $orgs := doc($config:data-root || "/organization/organization.xml")//tei:org
            return

            <div>
                <h3><pb-i18n key="mentions-of"/>{" " ||  $orgs[@xml:id = $key]/tei:orgName/text()}</h3>
                <div class="mentions">{
                        for $col in $config:data-collections
                            let $matches := collection($config:data-root || "/" || $col)//tei:TEI[.//tei:orgName/@ref = $key]
                            let $log := util:log("info", "app:mentions: col: " || $col || " - $matches: " || count($matches))
                            return
                                if(count($matches) > 0)
                                then (
                                    <h4><pb-i18n key="menu.{$col}"/></h4>,
                                    <ul>{app:ref-list("place", $matches, $col, $key)}</ul>
                                ) else()
                }</div>
            </div>
        )
        else ()
};
declare function app:ref-list($type, $list, $col, $key) {
    for $doc in $list
        let $doc-name := util:document-name($doc)
        let $log := util:log("info", "app:ref-list: name: " || $doc-name)
        let $idno := $doc//tei:seriesStmt//tei:idno/text()
        let $log := util:log("info", "app:ref-list: $idno: " || $idno)
        let $title := $doc//tei:msDesc/tei:head/text()
        let $log := util:log("info", "app:ref-list: $title: " || $title)
        return
            if($title)
            then (
                <li>
                    <a href="../../{$col}/{$idno}">
                        {$title}
                    </a>
                </li>
            ) else ()
};


declare
    %templates:wrap
function app:collection-title($node as node(), $model as map(*)) {
    let $collection-title := substring-before($model?doc, '/')
    return (
       common:format-id($collection-title)
    )
};

(:~ Helper function for Literaturverzeichnis 
 : The Introduction blurb of the bibliography  
 : TODO(DP): need confirmation that this is the blurb wanted by client
:)
declare function app:bibl-blurb() as element(p) {     
    let $blurb := $app:LITERATUR//tei:body/tei:div/tei:div/tei:div/tei:p/text()
    return
        <p>{$blurb}</p>
};

(:~ Helper function for Literaturverzeichnis 
 : Not all links go to BSG, but to … ?  
 : TODO(DP): find out new link target for non-BSG linksm should also be perma links no?
 :)
declare function app:bibl-link($idno as xs:string) as xs:string {     
    let $chbsg := 'http://permalink.snl.ch/bib/'
    let $non-bsg := '/suche/detail/'
    
    return
        if ($idno ! starts-with(., 'chbsg')) then ($chbsg || $idno)
        else ($non-bsg || $idno) 
};

(:~ Helper function for Literaturverzeichnis  
 : Table headers for bibliography tables  
 : without 'Zitiert in'
 : TODO(DP): add i18n entries <pb-i18n key="bibliography" /> 
 : @see app:bibl-quoted
 :)
declare function app:bibl-thead() as element(thead) {
    let $column-headings := ('Kurztitel', 'Bibliografische Angaben', 'Nachweis BSG')
    return
        <thead>
            <tr>
                { for $heading in $column-headings
                    return
                        <th>{$heading}</th>
                }
            </tr>
        </thead>

};

(:~ Helper function for Literaturverzeichnis 
 : Kurztitle
 :)
declare function app:bibl-short($node as node()) as element(td) {
    <td>{$node/tei:*/tei:title[@type="short"]/text()}</td>        
};

(:~ Helper function to get the named editors of edited volumes 
 : note  not all EV have named editors in their monogr
 : @param $secondary the container Work (Volume for article in Edited Volume) 
 : @see app:bibl-full
 :)
declare function app:bibl-editors($secondary as node()) as xs:string* {
        if (exists($secondary/tei:author)) 
        then (string-join($secondary/tei:author, '; ')) 
        else ()
};

(:~ Helper function to get the named imprint  of edited volumes 
 : note: some imprints are missing in source data
 : @see app:bibl-full
 :)
declare function app:bibl-ev-imprint($secondary as node()) as xs:string* {
    $secondary/tei:title[1]/string() || ", " || $secondary//tei:pubPlace[1] || " " || $secondary//tei:date[1] || ", " || $secondary//tei:biblScope[@unit = 'page']
};

(:~ Helper function to get the named imprint  of journals 
 : note some imprints are missing in source data
 : @param $secondary the container Work (journal for journal article)
 : @see app:bibl-full
 :)
declare function app:bibl-ja-imprint($secondary as node()) as xs:string* {
    $secondary/tei:title[1]/string() || ' ' || $secondary//tei:biblScope[@unit ='issue'] || ", " || $secondary//tei:date[1] || ", " || $secondary//tei:biblScope[@unit = 'page']
};

(:~ Helper function for Literaturverzeichnis 
 : Vollständige Bibliografische Angaben
 :
 : Monographie:
 : Nachname, Vorname: Titel, Erscheinungsort Jahr.
 :
 : Beitrag in Sammelband:
 : Nachname, Vorname: Titel, in: Vorname Nachname (Hg.), Titel Sammelband, Erscheinungsort Jahr, Seitenzahlen.
 :
 : Beitrag in Zeitschrift:
 : Nachname, Vorname: Titel, in: Titel Zeitschrift Nummer, Jahr, Seitenzahlen.
 :
 : TODO(DP): 
 : - Data Source is still missing datapoints:
 : - make display prettier for missing data no "Titel , , 313-4.
 : - configure index for faster loading
 :)
declare function app:bibl-full($node as node(), $type as xs:string) as xs:string {
    (: get primary bibliographical element for author and title (all) :)
    let $main := $node/*/tei:title[@type="short"]/..
    let $authors := string-join($main/tei:author, '; ')
    let $title := $main/tei:title[@type="full"]/string()

    (: assemble shared components :)
    let $start-all := $authors || ": " || $title || ", "

    (: get secondary for JA and EV :)
    let $secondary := if ($type eq 'W') then () else ($node/tei:monogr)
    
    return
        switch($type)
            case ('W') return $start-all || $node//tei:pubPlace[1] || " " || $node//tei:date || "."
            case ('EV') return $start-all || "in: " || app:bibl-editors($secondary) || " (Hg.) " || app:bibl-ev-imprint($secondary) || "."
            case ('JA') return $start-all || "in: " || app:bibl-ja-imprint($secondary) || "."         
        default return ()   
};

(:~ Helper function for Literaturverzeichnis 
 : @param $list one of the two listBibls in the Bibliographie file
 : @return caption containing the header belonging to that listBibl
 :)
declare function app:bibl-caption($list as node()) as xs:string {
        $list/../../tei:head/string()
};

(:~ Helper function for Literaturverzeichnis 
 : Checks for appearance of permalink in the bibliography within the data repo and returns the containing documents as links.
 : note $config:data-collections as better target for this function.
 : TODO(DP): what is the new link target for the quotations
 : @see app:bibl-link
 : @param permalink based on the xml:id of the quoted work to be found in the bibliography. 
 : @return a list of editions containing the quotations.
 :)
declare %private function app:bibl-quoted($permalink as xs:string) as element(ul) {
   <ul> {
    let $quotes := $config:data-root//tei:bibl/tei:ref[@target = $permalink] ! base-uri(.) 
        ! substring-after(., 'rqzh-data/') 
        ! substring-before(., '/') 
        => distinct-values()
    for $q in $quotes
    return
        <li><a href="." target="_blank">{$q}</a></li>    
   } </ul>
};

(:~ Generate tables for Literaturverzeichnis
 : Die Seite enthält: 
 : Kurztitel (ausschlaggebend für alphabetische Auflistung); 
 : vollständige bibliographische Angaben; 
 : Link zur BSG; 
 : Editionsstück(e) in dem der Literaturtitel zitiert wird. 
 : @see http://www.rechtsquellen-online.ch/startseite/literaturverzeichnis 
 : @see data/SSRQ_ZH_NF_Bibliographie_integral.xml
 : @return div element
 :)
declare
%templates:wrap
function app:bibliography($node as node(), $model as map(*)) as element(div){
    <div>
        { app:bibl-blurb() },
        {
            for $list in $app:LITERATUR//tei:body/*/*/*/tei:listBibl
            return
            <table>
                { app:bibl-thead() }
                <caption>{ app:bibl-caption($list) }</caption>
                <tbody>
                {
                    for $entry in $list/tei:biblStruct
                    let $id := data($entry/@xml:id)
                    let $type := data($entry/@type)
                    let $short := $entry/*/tei:title[@type = "short"]/text()
                    order by $short
                    return
                            <tr id="{ $id }">
                                <td>{ $short }</td>
                                <td>{ app:bibl-full($entry, $type) }</td>
                                <td><a href="{ app:bibl-link($id) }" target="_blank">BSG</a></td>
                            </tr>
                }
                </tbody>
            </table>
        }
    </div>
};
