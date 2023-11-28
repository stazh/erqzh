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
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace app="http://existsolutions.com/ssrq/app" at "app.xql";
import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "lib/pages.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace dapi="http://teipublisher.com/api/documents" at "lib/api/document.xql";
import module namespace vapi="http://teipublisher.com/api/view" at "lib/api/view.xql";

declare variable $api:REGISTER-LUCENE-OPTIONS := map {
                    "leading-wildcard": "yes",
                    "filter-rewrite": "yes"
                };

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

declare function api:about($request as map(*)) {
    let $_ := util:log("info", "api:about")
    let $doc := $config:data-root  || "/about/about-the-edition-de.xml"
    let $_ := util:log("info", "api:about doc: " || $doc)
    let $xml := pages:load-xml($config:default-view, (), $doc)
    let $_ := util:log("info", "api:about xml: ")
    let $_ := util:log("info", $xml?data)
    
    let $template := doc($config:app-root || "/templates/pages/view.html")
    let $_ := util:log("info", "api:about template: ")
    let $_ := util:log("info", $template)
    let $model := map {
        "data": $xml?data,
        "odd": $config:default-odd,
        "view": $config:default-view,
        "template": $config:default-template

    }
    return
        templates:apply($template, api:lookup#2, $model, map {
            $templates:CONFIG_APP_ROOT : $config:app-root,
            $templates:CONFIG_STOP_ON_ERROR : true()
        })
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

(:~
* retrieves all places as an json array 
* called by <pb-leaflet-map> component 
~:)
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
    (: let $log := util:log("info", "api:places-all found '" || count($places) || "' places in editionseinheit " || $editionseinheit) :)
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
declare function api:split-list($request as map(*)) {
    let $search := normalize-space($request?parameters?search)    
    let $letterParam := $request?parameters?category
    let $limit := $request?parameters?limit
    (: let $log := util:log("info","api:split-list $search:"||$search || " - $letterParam:"||$letterParam||" - $limit:" || $limit )  :)
    let $reg-type := normalize-space($request?parameters?type)
    let $editionseinheit := translate($request?parameters?editionseinheit, "/","")
    let $log := util:log("info","api:split-list: registry-type: " || $reg-type)
    let $items := api:query-register($reg-type,$search,$editionseinheit)
    let $log := util:log("info", "api:split-list found items: " || count($items))
    let $byLetter := 
        map:merge(
            for $item in $items
                let $name := ft:field($item, 'name')[1]
                order by $name
                group by $letter := substring($name, 1, 1) => upper-case()
                return
                    map:entry($letter, $item)
    )
    let $letter :=
        if ((count($items) < $limit) or $search != '') then
            "[A-Z]"
        else if (not($letterParam) or $letterParam = '') then
            head(sort(map:keys($byLetter)))
        else
            $letterParam
    let $itemsToShow :=
        if ($letter = '[A-Z]') then
            $items
        else
            $byLetter($letter)
    return
        map {
            "items": api:output-split-list-items($itemsToShow, $letter, $search, $reg-type),
            "categories":
                if ((count($items) < $limit)  or $search != '') then
                    []
                else array {
                    for $index in 1 to string-length('0123456789AÄBCDEFGHIJKLMNOÖPQRSTUÜVWXYZ')
                    let $alpha := substring('0123456789AÄBCDEFGHIJKLMNOÖPQRSTUÜVWXYZ', $index, 1)
                    let $hits := count($byLetter($alpha))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": "[A-Z]",
                        "count": count($items),
                        "label": <pb-i18n key="all">Alle</pb-i18n>
                    }
                }
        }
};

declare function api:query-register($reg-type as xs:string, $search as xs:string?, $editionseinheit as xs:string?) {
    (: let $_ := util:log("info","api:query-register $reg-type: " || $reg-type || " - $search " || $search || " - $editionseinheit: " || $editionseinheit ) :)
    let $volume-facet := if($editionseinheit = $config:data-collections) then (' AND volume:(' || $editionseinheit || ')' ) else ()
    let $facet-string := if ($search and $search != '')
                        then ( 'name:(' || $search || '*)' || $volume-facet)
                        else ( 'name:*' || $volume-facet)
    return
    switch($reg-type) 
        case "people" return
            if ($search and $search != '') 
            then ( $config:register-person//tei:person[ft:query(., $facet-string)] ) 
            else ( $config:register-person//tei:person[ft:query(., $facet-string, $api:REGISTER-LUCENE-OPTIONS)] )
        case "organization" return         
            if ($search and $search != '') 
            then ( $config:register-organization//tei:org[ft:query(., $facet-string)] ) 
            else ( $config:register-organization//tei:org[ft:query(., $facet-string, $api:REGISTER-LUCENE-OPTIONS)] )
        case "place" return 
            if ($search and $search != '') 
            then ( $config:register-place//tei:place[ft:query(., $facet-string)] ) 
            else ( $config:register-place//tei:place[ft:query(., $facet-string, $api:REGISTER-LUCENE-OPTIONS)] )
        case "keyword" return 
            if ($search and $search != '') 
            then ( $config:register-taxonomy//tei:category[ft:query(., $facet-string)] ) 
            else ( $config:register-taxonomy//tei:category[ft:query(., $facet-string, $api:REGISTER-LUCENE-OPTIONS)] )
        default return
            error($errors:NOT_FOUND, "Register type " || $reg-type || " not found")
};

declare function api:output-split-list-items($list, $letter as xs:string, $search as xs:string?, $reg-type) {
    array {
        for $item in $list
            let $name := ft:field($item, 'name')[1]
            return
            if(string-length($name)>0)
            then (
                let $letterParam := if ($letter = "[A-Z]") then substring($name, 1, 1) else $letter
                let $params := "&amp;category=" || $letterParam || "&amp;search=" || $search
                
                return
                    <span class="{$reg-type}">
                        <a href="{$name}?{$params}&amp;key={$item/@xml:id}">{$name}</a>
                        { api:output-split-list-items-details($item, $reg-type)}
                    </span>
            ) else()
    }
};

declare function api:output-split-list-items-details($item, $reg-type) {
    switch($reg-type) 
        case "people" return
            let $dates := $item/tei:note[@type="date"]/text()
            return if($dates) then ( <span class="dates"> ({$dates})</span> ) else ()
        case "organization" return
            let $type := substring-before($item/@type/string(),"/")
            return if ($type) then <span class="type"> ({$type})</span> else ()        
        case "place" return
            let $label := $item/@n/string()
            let $type := substring-before($item/tei:trait[@type="type"][1]/tei:label/text(), "/")
            let $coords := tokenize($item/tei:location/tei:geo)
            return (
                if (string-length($type) > 0) then <span class="type"> ({$type})</span> else (),
                if(string-length(normalize-space($item/tei:location/tei:geo)) > 0) 
                then (
                    element pb-geolocation {
                        attribute latitude { $coords[1] },
                        attribute longitude { $coords[2] },
                        attribute label { $label},
                        attribute emit {"map"},
                        attribute event { "click" },
                        if ($item/@type != 'approximate') then attribute zoom { 9 } else (),
                        
                        element iron-icon {
                            attribute icon {"maps:map" }
                        }
                    }
                ) 
                else ()
        )
        case "keyword" return ()
        default return
            error($errors:NOT_FOUND, "Register type " || $reg-type || " not found")    

};

declare function api:sort($items as array(*)*, $dir as xs:string) {
    let $sorted :=
        sort($items, "?lang=de-DE", function($entry) {
            $entry?1
        })
    return
        if ($dir = "asc") then
            $sorted
        else
            reverse($sorted)
};

declare function api:facets-search($request as map(*)) {
    let $value := $request?parameters?value
    let $query := $request?parameters?query
    let $type := $request?parameters?type
    let $lang := tokenize($request?parameters?language, '-')[1]

    let $_ := util:log("info", ("api:facets-search type: '", $type, "' - query: '" , $query, "' - value: '" , $value, "'"))    
    let $hits := session:get-attribute($config:session-prefix || ".hits")
    let $log := util:log("info", "api:facets-search: hits: " || count($hits))
    let $facets := ft:facets($hits, $type, ())
    let $log := util:log("info", "api:facets-search: $facets: " || count($facets))

    
    let $matches := 
        for $key in if (exists($request?parameters?value)) 
                            then $request?parameters?value 
                            else map:keys($facets)
            let $text := 
                switch($type) 
                    case "archive" return
                        $key
                    case "person" return
                        $config:register-person/id($key)/tei:persName[@type='full']/text()
                    case "organization" return
                        $config:register-organization/id($key)/tei:orgName/text()
                    case "place" return
                        $config:register-place/id($key)/tei:placeName[@type='main']/text()
                    case "keyword" return
                        $config:register-taxonomy/id($key)/tei:desc[@xml:lang='deu']/text()
                    case "filiation" return $key
                    case "material" return
                        let $i18n-path := $config:app-root || "/resources/i18n/app/" ||  $lang || ".json"
                        let $json := json-doc($i18n-path)
                        let $_ := util:log("info", "api:facets-search: material: $key : " || $key || " - $i18n-path: " || $i18n-path)
                        return
                            $json?($key)
                    default return 
                        let $_ := util:log("warn", "api:facets-search: default return, $type: " || $type)
                        return 
                            $key
            return 
                map {
                    "text": $text,
                    "freq": $facets($key),
                    "value": $key
                } 


           
        let $log := util:log("info", "api:facets-search: $matches: " || count($matches))
        let $filtered := filter($matches, function($item) {
            matches($item?text, '(?:^|\W)' || $request?parameters?query, 'i')
        })
        let $log := util:log("info", "api:facets-search: filtered $matches: " || count($filtered))
        return
            array { $filtered }
};

declare function api:facet-titles($request as map(*)) {
    let $lang := ($request?parameters?lang, $config:default-language )[1]
    let $hits := session:get-attribute($config:session-prefix || ".hits")
    let $facets := ft:facets($hits, "volume", ())
    let $facet-title := $request?parameters?facet-volume
    

    let $volumes :=
        for $vol in $config:data-collections
            let $title :=  switch($vol)
                case "ZH_NF_I_1_3" return "Stadt und Territorialstaat Zürich II"
                case "ZH_NF_I_1_11" return "Gedruckte Mandate Zürich"
                case "ZH_NF_I_2_1" return "Die Rechtsquellen der Stadt Winterthur"
                case "ZH_NF_II_3" return "Die Landvogtei Greifensee"
                case "ZH_NF_II_11" return "Die Obervogteien um die Stadt Zürich"
                default return $vol
            
            return map {
                "title": $title,
                "value": $vol,
                "hits": ($facets?($vol), 0)[1]
        }

    return
        <fieldset>
            <legend><pb-i18n key="volume"></pb-i18n></legend>
        {
            for $vol in $volumes
            let $checked := $vol?value = $facet-title
            (: let $_ := util:log("info", map {
                "vol":$vol?value,
                "param":$facet-title, 
                "checked":$vol?value = $facet-title
            }) :)
            return
                element paper-checkbox {
                    attribute type { "checkbox" },
                    attribute name { "facet-volume" },
                    (: if ($j?hits = 0) then attribute disabled { "disabled" } else (), :)
                    if ($checked) then attribute checked { "checked" } else (),
                    attribute value { $vol?value },
                    $vol?title 
                    (: || " (" || $j?hits || ")" :)
                }
        }
        </fieldset>
};