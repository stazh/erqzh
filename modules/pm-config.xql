xquery version "3.1";

module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config";

import module namespace pm-rqzh-web="http://www.tei-c.org/pm/models/rqzh/web/module" at "../transform/rqzh-web-module.xql";
import module namespace pm-docx-tei="http://www.tei-c.org/pm/models/docx/tei/module" at "../transform/docx-tei-module.xql";
import module namespace pm-rqzh-norm-web="http://www.tei-c.org/pm/models/rqzh-norm/web/module" at "../transform/rqzh-norm-web-module.xql";

declare variable $pm-config:web-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "rqzh.odd" return pm-rqzh-web:transform($xml, $parameters)
case "rqzh-norm.odd" return pm-rqzh-norm-web:transform($xml, $parameters)
    default return pm-rqzh-web:transform($xml, $parameters)
};

declare variable $pm-config:tei-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "docx.odd" return pm-docx-tei:transform($xml, $parameters)
    default return error(QName("http://www.tei-c.org/tei-simple/pm-config", "error"), "No default ODD found for output mode tei")
};