xquery version "3.1";

(:~
 : Non-standard extension functions, mainly used for the documentation.
 :)
module namespace pmf="http://www.tei-c.org/tei-simple/xquery/ext-fo";

import module namespace print="http://www.tei-c.org/tei-simple/xquery/functions/fo";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace fo="http://www.w3.org/1999/XSL/Format";

declare function pmf:alternote($config as map(*), $node as element(), $class as xs:string+, $content,
    $label, $type, $alternate) {
    print:inline($config, $node, $class, $content),
    print:note($config, $node, $class, $alternate, (), ())
};

declare function pmf:alternate($config as map(*), $node as node(), $class as xs:string+, $content, $default,
    $alternate) {
    $config?apply-children($config, $node, $content),
    print:note($config, $node, $class, $alternate, (), ())
};

declare function pmf:reference($config as map(*), $node as element(), $class as xs:string+, $content,
    $ref, $label) {
    pmf:alternate($config, $node, $class, (), $content, $label)
};

declare function pmf:notespan-end($config as map(*), $node as element(), $class as xs:string+, $content) {
    ()
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

declare function pmf:content($config as map(*), $node as node(), $class as xs:string+, $content as item()*) {
    typeswitch($content)
        case attribute() return
            text { $content }
        case text() return
            $content
        default return
            text { $content }
};