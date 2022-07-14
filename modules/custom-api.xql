xquery version "3.1";

(:~
 : This is the place to import your own XQuery modules for either:
 :
 : 1. custom API request handling functions
 : 2. custom templating functions to be called from one of the HTML templates
 :)
module namespace api="http://teipublisher.com/api/custom";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(: Add your own module imports here :)
import module namespace rutil="http://exist-db.org/xquery/router/util";
import module namespace errors = "http://exist-db.org/xquery/router/errors";
import module namespace app="http://existsolutions.com/ssrq/app" at "app.xql";
import module namespace search="http://existsolutions.com/ssrq/search" at "ssrq-search.xql";
import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "lib/pages.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace dapi="http://teipublisher.com/api/documents" at "lib/api/document.xql";
import module namespace vapi="http://teipublisher.com/api/view" at "lib/api/view.xql";


(:~
 : Keep this. This function does the actual lookup in the imported modules.
 :)
declare function api:lookup($name as xs:string, $arity as xs:integer) {
    try {
        function-lookup(xs:QName($name), $arity)
    } catch * {
        ()
    }
};

declare function api:registerdaten($request as map(*)) {
    let $doc := xmldb:decode-uri($request?parameters?id)
    let $view := head(($request?parameters?view, $config:default-view))
    let $xml := pages:load-xml($view, (), $doc)
    let $template := doc($config:app-root || "/templates/facets.html")
    let $model := map {
        "data": $xml?data,
        "template": "facets.html",
        "odd": $xml?config?odd
    }
    return
        templates:apply($template, api:lookup#2, $model, map {
            $templates:CONFIG_APP_ROOT : $config:app-root,
            $templates:CONFIG_STOP_ON_ERROR : true()
        })
};

declare function api:abbreviations($request as map(*)) {
    let $lang := tokenize($request?parameters?language, '-')[1]
    let $blocks := $config:abbr//tei:dataSpec/tei:desc[@xml:lang=$lang]

    return
        for $block in $blocks
        return
            <div>
                <h3>{$block}</h3>

                {
                    for $item in $block/../tei:valList/tei:valItem
                    return
                        <li>
                            {$item/@ident/string()} = {($item/tei:desc[@xml:lang=$lang], $item/tei:desc[1])[1]/text()}
                        </li>
                }
            </div>
};

(: NOTE(DP): not in use due to performance :)
declare function api:bibliography($request as map(*)) {
    app:bibliography(<div/>, $request?parameters)
};


declare function api:partners($request as map(*)) {
    let $lang := $request?parameters?language
    for $partner in $config:partners//tei:dataSpec/tei:valList/tei:valItem return
        <div>
            <h3>
                { data($partner/@ident) }
            </h3>
            { $partner/tei:desc[@xml:lang=$lang] }
        </div>
};

declare function api:html($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?id)
    return
        if ($doc) then
            let $xml := config:get-document($doc)/*
            return
                if (exists($xml)) then
                    let $config := tpu:parse-pi(root($xml), ())
                    let $metadata := $pm-config:web-transform($xml, map { "root": $xml, "view": "metadata", "webcomponents": 7}, $config?odd)
                    let $content := $pm-config:web-transform($xml//tei:body, map { "root": $xml, "webcomponents": 7 }, $config?odd)
                    let $locales := "resources/i18n/{{ns}}/{{lng}}.json"
                    let $page :=
                            <html>
                                <head>
                                    <meta charset="utf-8"/>
                                    <link rel="stylesheet" type="text/css" href="resources/css/theme.css"/>
                                    <link rel="stylesheet" type="text/css" href="resources/css/theme-rqzh.css"/>
                                </head>
                                <body class="printPreview">
                                    <paper-button id="closePage" class="hidden-print" onclick="window.close()" title="close this page">
                                        <paper-icon-button icon="close"></paper-icon-button>
                                        Close Page
                                    </paper-button>
                                    <paper-button id="printPage" class="hidden-print" onclick="window.print()" title="print this page">
                                        <paper-icon-button icon="print"></paper-icon-button>
                                        Print Page
                                    </paper-button>

                                    <pb-page unresolved="unresolved" locales="{$locales}" locale-fallback-ns="app" require-language="require-language" api-version="1.0.0">
                                        { $metadata }
                                        <h4 class="block-title edition">
                                            <pb-i18n key="editiontext"/>
                                        </h4>
                                        { $content }
                                    </pb-page>
                                    <script>
                                        window.addEventListener('WebComponentsReady', function() {{
                                            document.querySelectorAll('pb-collapse').forEach(function(collapse) {{
                                                collapse.opened = true;
                                            }});
                                        }});
                                    </script>
                                </body>
                            </html>
                    return
                        dapi:postprocess($page, (), $config?odd, $config:context-path || "/", true())
                else
                    error($errors:NOT_FOUND, "Document " || $doc || " not found")
        else
            error($errors:BAD_REQUEST, "No document specified")
};

declare function api:timeline($request as map(*)) {
    let $entries := session:get-attribute($config:session-prefix || '.hits')
    let $datedEntries := filter($entries, function($entry) {
            try {
                let $date := ft:field($entry, "date-min", "xs:date")
                return
                        exists($date) and year-from-date($date) != 1000
            } catch * {
                false()
            }
        })
    return
        map:merge(
            for $entry in $datedEntries
            group by $date := ft:field($entry, "date-min", "xs:date")
            return
                map:entry(format-date($date, "[Y0001]-[M01]-[D01]"), map {
                    "count": count($entry),
                    "info": ''
                })
        )
};

declare function api:places-all($request as map(*)) {
    let $editionseinheit := translate($request?parameters?editionseinheit, "/","")
    let $places := 
        if( $editionseinheit = $config:data-collections )
        then (
            doc($config:data-root || "/place/place-" || $editionseinheit || ".xml")//tei:listPlace/tei:place    
        )
        else (
            doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place
        )
    let $log := util:log("info", "api:places-all found '" || count($places) || "' places in editionseinheit " || $editionseinheit)
    return 
        array { 
            for $place in $places
            return
                if(string-length(normalize-space($place/tei:location/tei:geo)) > 0)
                then (
                    let $tokenized := tokenize($place/tei:location/tei:geo)
                    return 
                        map {
                            "latitude":$tokenized[1],
                            "longitude":$tokenized[2],
                            "label":$place/@n/string(),
                            "id":$place/@xml:id/string()
                        }
                ) else()
            }        
};

declare function api:people($request as map(*)) {
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $view := $request?parameters?view
    let $sortDir := $request?parameters?dir
    let $limit := $request?parameters?limit
    let $editionseinheit := translate($request?parameters?editionseinheit, "/","")
    let $log := util:log("info","api:people $search:"||$search || " - $letterParam:"||$letterParam||" - $limit:" || $limit || " - $editionseinheit:" || $editionseinheit)
    let $peoples := if( $editionseinheit = $config:data-collections )
                            then (
                                if ($search and $search != '') 
                                then (
                                    doc($config:data-root || "/person/person-" || $editionseinheit || ".xml")//tei:person[ft:query(., 'name:(' || $search || '*)')]
                                ) else (
                                    doc($config:data-root || "/person/person-" || $editionseinheit || ".xml")//tei:person
                                )
                            )
                            else (
                                if ($search and $search != '') 
                                then (
                                    doc($config:data-root || "/person/person.xml")//tei:person[ft:query(., 'name:(' || $search || '*)')]    
                                ) 
                                else (
                                    doc($config:data-root || "/person/person.xml")//tei:person
                                )
                            )
    let $sorted_peoples := for $people in $peoples 
                            order by $people/tei:persName[@type='sorted_full'] ascending
                            return
                                $people
    let $log := util:log("info","api:people  found people:"||count($sorted_peoples) )
    let $byKey := for-each($sorted_peoples, function($person as element()) {
        let $label := $person/tei:persName[@type='full_sorted']/text()
        let $sortKey :=
            if (starts-with($label, "von ")) then
                substring($label, 5)
            else
                $label
        return
            [lower-case($sortKey), $label, $person]
    })
    let $sorted := api:sort($byKey, $sortDir)
    let $letter := 
        if (count($sorted_peoples) < $limit) then 
            "Alle"
        else if (not($letterParam) or $letterParam = '') then (
            substring($sorted[1]?1, 1, 1) => upper-case()
        )
        else
            $letterParam
    let $byLetter :=
        if ($letter = 'Alle') then
            $sorted
        else
            filter($sorted, function($entry) {
                starts-with($entry?1, lower-case($letter))
            })

    return
        map {
            "items": api:output-person($byLetter, $letter, $view, $search),
            "categories":
                if (count($sorted_peoples) < $limit) then
                    []
                else array {
                    for $index in 1 to string-length('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
                    let $alpha := substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ', $index, 1)
                    let $hits := count(filter($sorted, function($entry) { starts-with($entry?1, lower-case($alpha))}))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": "Alle",
                        "count": count($sorted)
                    }
                }
        }
};

declare function api:output-person($list, $letter as xs:string, $view as xs:string, $search as xs:string?) {
    array {
        for $person in $list
            let $dates := $person?3/tei:note[@type="date"]/text()
            let $letterParam := if ($letter = "Alle") then substring($person?3/tei:persName[@type='full_sorted']/text(), 1, 1) else $letter
            let $params := "category=" || $letterParam || "&amp;view=" || $view || "&amp;search=" || $search
            return
                <span>
                    <a href="{$person?3/tei:persName[@type='full_sorted']/text()}?{$params}&amp;key={$person?3/@xml:id}">{$person?2}</a>
                    { if ($dates) then <span class="dates"> ({$dates})</span> else () }
                </span>
    }
};

declare function api:organizations($request as map(*)) {
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $view := $request?parameters?view
    let $sortDir := $request?parameters?dir
    let $limit := $request?parameters?limit
    let $editionseinheit := translate($request?parameters?editionseinheit, "/","")
    let $log := util:log("info","api:organizations $search:"||$search || " - $letterParam:"||$letterParam||" - $limit:" || $limit || " - $editionseinheit:" || $editionseinheit)
    let $orgs := if( $editionseinheit = $config:data-collections )
                    then (
                        if ($search and $search != '') 
                        then (
                            doc($config:data-root || "/organization/organization-" || $editionseinheit || ".xml")//tei:org[ft:query(., 'org-name:(' || $search || '*)')]
                        ) else (
                            doc($config:data-root || "/organization/organization-" || $editionseinheit || ".xml")//tei:org
                        )
                    )
                    else (
                        if ($search and $search != '') 
                        then (
                            doc($config:data-root || "/organization/organization.xml")//tei:org[ft:query(., 'org-name:(' || $search || '*)')]    
                        ) 
                        else (
                            doc($config:data-root || "/organization/organization.xml")//tei:org
                        )
                    )
    let $log := util:log("info","api:organizations  found orgs:"||count($orgs) )
    let $byKey := for-each($orgs, function($org as element()) {
        let $label := $org/tei:orgName/text()
        return
            [lower-case($label), $label, $org]
    })
    let $sorted := api:sort($byKey, $sortDir)
    let $letter := 
        if (count($orgs) < $limit) then 
            "Alle"
        else if (not($letterParam) or $letterParam = '') then (
            substring($sorted[1]?1, 1, 1) => upper-case()
        )
        else
            $letterParam
    let $byLetter :=
        if ($letter = 'Alle') then
            $sorted
        else
            filter($sorted, function($entry) {
                starts-with($entry?1, lower-case($letter))
            })

    return
        map {
            "items": api:output-organization($byLetter, $letter, $view, $search),
            "categories":
                if (count($orgs) < $limit) then
                    []
                else array {
                    for $index in 1 to string-length('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
                    let $alpha := substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ', $index, 1)
                    let $hits := count(filter($sorted, function($entry) { starts-with($entry?1, lower-case($alpha))}))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": "Alle",
                        "count": count($sorted)
                    }
                }
        }
};

declare function api:output-organization($list, $letter as xs:string, $view as xs:string, $search as xs:string?) {
    array {
        for $org in $list
            let $type := substring-before($org?3/@type/string(),"/")
            let $letterParam := if ($letter = "Alle") then substring($org?3/tei:orgName/text(), 1, 1) else $letter
            let $params := "category=" || $letterParam || "&amp;view=" || $view || "&amp;search=" || $search
            return
                <span>
                    <a href="{$org?3/tei:orgName/text()}?{$params}&amp;key={$org?3/@xml:id}">{$org?2}</a>
                    { if ($type) then <span class="type"> ({$type})</span> else () }
                </span>
    }
};

declare function api:sort($people as array(*)*, $dir as xs:string) {
    let $sorted :=
        sort($people, "?lang=de-DE", function($entry) {
            $entry?1
        })
    return
        if ($dir = "asc") then
            $sorted
        else
            reverse($sorted)
};

declare function api:places($request as map(*)) {
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $limit := $request?parameters?limit
    let $editionseinheit := translate($request?parameters?editionseinheit, "/","")
    let $log := util:log("info","api:places $search:"||$search || " - $letterParam:"||$letterParam||" - $limit:" || $limit || " - $editionseinheit:" || $editionseinheit)
    let $places := if( $editionseinheit = $config:data-collections )
                            then (
                                if ($search and $search != '') 
                                then (
                                    doc($config:data-root || "/place/place-" || $editionseinheit || ".xml")//tei:listPlace/tei:place[ft:query(., 'lname:(' || $search || '*)')]
                                ) else (
                                    doc($config:data-root || "/place/place-" || $editionseinheit || ".xml")//tei:listPlace/tei:place    
                                )
                            )
                            else (
                                if ($search and $search != '') 
                                then (
                                    doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place[ft:query(., 'lname:(' || $search || '*)')]
                                ) else (
                                    doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place
                                )
                            )
    let $log := util:log("info","api:places  found places:"||count($places) )
    let $sorted := sort($places, "?lang=de-DE", function($place) { lower-case($place/@n) })
    
    let $letter := 
        if (count($places) < $limit) then 
            "Alle"
        else if (not($letterParam) or $letterParam = '') then
            substring($sorted[1], 1, 1) => upper-case()
        else
            $letterParam
    let $log := util:log("info","api:places  $letter:"||$letter )            
    
    let $byLetter :=
        if ($letter = 'Alle') then
            $sorted
        else
            filter($sorted, function($entry) {
                starts-with(lower-case($entry/@n), lower-case($letter))
            })
    return
        map {
            "items": api:output-place($byLetter, $letter, $search),
            "categories":
                if (count($places) < $limit) then
                    []
                else array {
                    for $index in 1 to string-length('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
                    let $alpha := substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ', $index, 1)
                    let $hits := count(filter($sorted, function($entry) { starts-with(lower-case($entry/@n), lower-case($alpha))}))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": "Alle",
                        "count": count($sorted)
                    }
                }
        }
};

declare function api:output-place($list, $category as xs:string, $search as xs:string?) {
    array {
        for $place in $list
        let $categoryParam := if ($category = "Alle") then substring($place/@n, 1, 1) else $category
        let $params := "category=" || $categoryParam || "&amp;search=" || $search || "&amp;key=" || $place/@xml:id
        let $label := $place/@n/string()
        let $type := substring-before($place/tei:trait[@type="type"][1]/tei:label/text(), "/")
        let $coords := tokenize($place/tei:location/tei:geo)
        return
            element span {
                attribute class { "place" },
                element span {
                    element a {
                        attribute href { $label || "?" || $params },
                        $label
                    },
                    if (string-length($type) > 0) then <span class="type"> ({$type})</span> else () 
                },
                if(string-length(normalize-space($place/tei:location/tei:geo)) > 0) 
                then (
                    element pb-geolocation {
                        attribute latitude { $coords[1] },
                        attribute longitude { $coords[2] },
                        attribute label { $label},
                        attribute emit {"map"},
                        attribute event { "click" },
                        if ($place/@type != 'approximate') then attribute zoom { 9 } else (),
                        
                        element iron-icon {
                            attribute icon {"maps:map" }
                        }
                    }
                ) 
                else () 
            }
    }
};

declare function api:html-places($request as map(*)) {
    let $path := $config:app-root || "/templates/" || xmldb:decode($request?parameters?file) || ".html"
    let $template :=
        if (doc-available($path)) then
            doc($path)
        else
            error($errors:NOT_FOUND, "HTML file " || $path || " not found")
    return
        templates:apply($template, vapi:lookup#2 , map { "editionseinheit":$request?parameters?editionseinheit } , $vapi:template-config)
};

declare function api:html-place($request as map(*)) {
    let $path := $config:app-root || "/templates/" || xmldb:decode($request?parameters?file) || ".html"
    let $template :=
        if (doc-available($path)) then
            doc($path)
        else
            error($errors:NOT_FOUND, "HTML file " || $path || " not found")
    return
        templates:apply($template, vapi:lookup#2 , map { "editionseinheit":$request?parameters?editionseinheit,"name":$request?parameters?name } , $vapi:template-config)
};
