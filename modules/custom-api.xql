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
import module namespace app="http://existsolutions.com/ssrq/app" at "ssrq.xql";
import module namespace search="http://existsolutions.com/ssrq/search" at "ssrq-search.xql";
import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "lib/pages.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "util.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace dapi="http://teipublisher.com/api/documents" at "lib/api/document.xql";

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
                                    <link rel="stylesheet" type="text/css" href="resources/css/theme-ssrq.css"/>
                                </head>
                                <body>
                                    <pb-page unresolved="unresolved" locales="{$locales}" locale-fallback-ns="app" require-language="require-language" api-version="1.0.0">
                                        { $metadata }
                                        <h4 class="block-title">
                                            <pb-i18n key="editiontext"/>
                                        </h4>
                                        { $content }
                                    </pb-page>
                                </body>
                            </html>
                    return
                        dapi:postprocess($page, (), $config?odd, $config:context-path || "/", true())
                else
                    error($errors:NOT_FOUND, "Document " || $doc || " not found")
        else
            error($errors:BAD_REQUEST, "No document specified")
};