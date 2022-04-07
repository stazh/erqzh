xquery version "3.1";

(:~
 : Extension functions for SSRQ.
 :)
module namespace pmf="http://www.tei-c.org/tei-simple/xquery/functions/ssrq-web";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace html="http://www.tei-c.org/tei-simple/xquery/functions";
import module namespace pmc="http://www.tei-c.org/tei-simple/xquery/functions/ssrq-common" at "ext-common.xql";

declare function pmf:link($config as map(*), $node as node(), $class as xs:string+, $content, $link, $target) {
    <a href="{$link}" class="{$class}">
    {
        if ($target) then
            attribute target { $target }
        else
            (),
        html:apply-children($config, $node, $content)
    }</a>
};

declare function pmf:output-date($config as map(*), $node as element(), $class as xs:string+, $content) {
    
    let $header := $node
    let $filiation := $header/tei:fileDesc//tei:msDesc/tei:msContents/tei:msItem/tei:filiation[@type='original'][tei:origDate]
    let $origin := $header/tei:fileDesc//tei:msDesc/tei:history/tei:origin
    let $origDate := if (exists($filiation)) then $filiation/tei:origDate else $origin/tei:origDate
    let $origPlace := if (exists($filiation)) then $filiation/tei:origPlace else $origin/tei:origPlace
    let $content := 
        if ($origDate/@from) then
            pmf:show-if-exists($node, $origDate/@from, function() {
                string-join((
                    pmc:print-date($origDate),
                    $origPlace
                ), ". ")
            })
        else
            pmf:show-if-exists($node, $origDate/@when, function() {
                string-join((
                    try {
                        format-date(xs:date($origDate/@when), '[Y] [MNn] [D1]', (session:get-attribute("ssrq.lang"), "de")[1], (), ())
                    } catch * {
                        $origDate/@when/string()
                    },
                    $origPlace
                ), ". ")
            })  
    return    
        <h5>{$content/text()}</h5>
};

declare %private function pmf:show-if-exists($node as node(), $test as node()*, $func as function(*)) {
    if ($test and normalize-space($test[1]/string()) != "") then
        element { node-name($node) } {
            $node/@*,
            $func()
        }
    else
        ()
};

declare function pmf:alternote($config as map(*), $node as element(), $class as xs:string+, $content,
    $label, $type, $alternate, $optional as map(*)) {
    let $nodeId :=
        if ($node/@exist:id) then
            $node/@exist:id
        else
            util:node-id($node)
    let $id := translate($nodeId, "-", "_")
    let $nr := pmc:increment-counter($type)
    let $alternate := $config?apply-children($config, $node, $alternate)
    let $prefix := $config?apply-children($config, $node, $optional?prefix)
    let $label :=
        switch($type)
            case "text-critical" return
                pmc:footnote-label($nr)
            default return
                $nr
    let $enclose := $type = "text-critical" and matches($content, "\s")
    let $labelStart := string-join(($label, if ($enclose) then "–" else ()))
    let $labelEnd := string-join((if ($enclose) then "–" else (), $label))
    return (
        <pb-popover class="alternate {$class}">
            <span slot="default">
                {
                    if ($enclose) then
                        <span class="note-wrap">
                            <a class="note note-start" rel="footnote" href="#fn:{$id}">
                            { $labelStart }
                            </a>
                        </span>
                    else
                        ()
                }
                { html:apply-children($config, $node, $content) }
                <span id="fnref_{$id}" class="note-wrap">
                    <a class="note note-end" rel="footnote" href="#fn_{$id}">
                    { $labelEnd }
                    </a>
                </span>
            </span>
            <template slot="alternate">{$prefix}{$alternate}</template>
        </pb-popover>,
        <li class="footnote" id="fn_{$id}" value="{$nr}"
            type="{if ($type = 'text-critical') then 'a' else '1'}">
            <span class="fn-content">
                {$prefix}{$alternate}
            </span>
            <a class="fn-back" href="#fnref_{$id}">↩</a>
        </li>
    )
};

declare function pmf:note($config as map(*), $node as element(), $class as xs:string+, $content, $place, $label, $type, $optional as map(*)) {
    switch ($place)
        case "margin" return
            if ($label) then (
                <span class="margin-note-ref">{$label}</span>,
                <span class="margin-note">
                    <span class="n">{$label/string()}) </span>{ $config?apply-children($config, $node, $content) }
                </span>
            ) else
                <span class="margin-note">
                { $config?apply-children($config, $node, $content) }
                </span>
        default return
            let $nodeId :=
                if ($node/@exist:id) then
                    $node/@exist:id
                else
                    util:node-id($node)
            let $id := translate($nodeId, "-", "_")
            let $nr := pmc:increment-counter($type)
            let $content := $config?apply-children($config, $node, $content)
            let $prefix := $config?apply-children($config, $node, $optional?prefix)
            let $n :=
                switch($type)
                    case "text-critical" case "text-critical-start" return
                        pmc:footnote-label($nr)
                    default return
                        $nr
            return (
                <a id="fnref_{$id}" class="note {$class}" rel="footnote" href="#fn_{$id}" data-label="{$n}">
                    { if ($type = "text-critical-start") then $n || "–" else $n }
                </a>,
                <li class="footnote" id="fn_{$id}" value="{$nr}"
                    type="{if ($type = ('text-critical','text-critical-start')) then 'a' else '1'}">
                    <span class="fn-content">
                        {$prefix}{$content}
                    </span>
                    <a class="fn-back" href="#fnref_{$id}">↩</a>
                </li>,
                <pb-popover for="fnref_{$id}" class="footnote">
                    {$prefix}{$content}
                </pb-popover>
            )
};

declare function pmf:notespan-end($config as map(*), $node as element(), $class as xs:string+, $content) {
    let $nodeId :=
        if ($content/@exist:id) then
            $content/@exist:id
        else
            util:node-id($content)
    let $id := translate($nodeId, "-", "_")
    return
        <tei-endnote class="note" rel="footnote" href="#fn_{$id}"/>
};

declare function pmf:finish($config as map(*), $input as node()*) {
    pmf:finish($config, $input, ())
};

declare function pmf:finish($config as map(*), $nodes as node()*, $popover as element(pb-popover)?) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(li) return
                if ($node/@class = 'footnote') then
                    element { node-name($node) } {
                        $node/@*,
                        pmf:finish($config, util:expand($node/node()), ())
                    }
                else
                    element { node-name($node) } {
                        $node/@*,
                        pmf:finish($config, $node/node(), $popover)
                    }
            case element(tei-endnote) return
                let $start := root($node)//a[@href = $node/@href]
                return
                    <span class="note-wrap">
                        <a>
                        {
                            $node/@*,
                            "–" || $start/@data-label
                        }
                        </a>
                    </span>
            case element(pb-popover) return
                if ($node/@class="footnote") then
                    $node
                else if ($node//pb-popover) then
                    pmf:finish($config, $node/*[@slot="default"]/node(), $node)
                else if ($popover) then
                    let $alternates := ($node/*[@slot="alternate"], $node/ancestor::pb-popover/*[@slot="alternate"])
                    let $refs := $alternates/../@data-ref
                    return
                        <pb-popover>
                        {
                            $node/@* except ($node/@data-ref, $node/@class),
                            if ($refs) then
                                attribute data-ref { string-join($refs, ' ') }
                            else
                                (),
                            attribute class {
                                string-join(($node/@class, $alternates/ancestor::pb-popover[1]/@class), ' ')
                            },
                            $node/*[@slot="default"],
                            <template slot="alternate">
                                <ol>
                                {
                                    for $alt in $alternates
                                    return
                                        <li>
                                        { 
                                            $alt/ancestor::pb-popover[1]/@data-ref
                                        }
                                        {$alt/node()}
                                        </li>
                                }
                                </ol>
                            </template>
                        }
                        </pb-popover>
                else
                    $node
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    pmf:finish($config, $node/node(), $popover)
                }
            default return
                if ($popover) then
                   <pb-popover>
                    {
                        $popover/@*,
                        <span slot="default">
                        { $node }
                        </span>,
                        $popover/*[@slot="alternate"]
                    }
                    </pb-popover>
                else
                    $node
};

declare function pmf:copy($config as map(*), $node as element(), $class as xs:string+, $content) {
    $content ! $config?apply($config, pmf:copy(.))
};

declare %private function pmf:copy($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    pmf:copy($node/node())
                }
            default return $node
};

declare function pmf:caption($config as map(*), $node as element(), $class as xs:string+, $content) {
    <caption class="{$class}">{html:apply-children($config, $node, $content)}</caption>
};


declare function pmf:content($config as map(*), $node as node(), $class as xs:string+, $content as item()*) {
    typeswitch($content)
        case attribute() return
            text { $content }
        case text() return
            $content
        default return
            text { $content }
};
