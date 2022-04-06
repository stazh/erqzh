xquery version "3.1";

module namespace app="http://existsolutions.com/ssrq/app";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
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
        root($model?data)//tei:persName/@ref |
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
    let $thumbnail-src := $work//tei:body//tei:pb[@n='1']/@facs/string()

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
function app:collection-title($node as node(), $model as map(*)) {
    let $collection-title := substring-before($model?doc, '/')
    return (
       common:format-id($collection-title)
    )
};

