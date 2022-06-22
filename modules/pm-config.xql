
xquery version "3.1";

module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config";

import module namespace pm-rqzh-web="http://www.tei-c.org/pm/models/rqzh/web/module" at "../transform/rqzh-web-module.xql";
import module namespace pm-rqzh-print="http://www.tei-c.org/pm/models/rqzh/fo/module" at "../transform/rqzh-print-module.xql";
import module namespace pm-rqzh-latex="http://www.tei-c.org/pm/models/rqzh/latex/module" at "../transform/rqzh-latex-module.xql";
import module namespace pm-rqzh-epub="http://www.tei-c.org/pm/models/rqzh/epub/module" at "../transform/rqzh-epub-module.xql";
import module namespace pm-docx-tei="http://www.tei-c.org/pm/models/docx/tei/module" at "../transform/docx-tei-module.xql";
import module namespace pm-rqzh-norm-web="http://www.tei-c.org/pm/models/rqzh-norm/web/module" at "../transform/rqzh-norm-web-module.xql";
import module namespace pm-rqzh-norm-print="http://www.tei-c.org/pm/models/rqzh-norm/fo/module" at "../transform/rqzh-norm-print-module.xql";
import module namespace pm-rqzh-norm-latex="http://www.tei-c.org/pm/models/rqzh-norm/latex/module" at "../transform/rqzh-norm-latex-module.xql";
import module namespace pm-rqzh-norm-epub="http://www.tei-c.org/pm/models/rqzh-norm/epub/module" at "../transform/rqzh-norm-epub-module.xql";

declare variable $pm-config:web-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "rqzh.odd" return pm-rqzh-web:transform($xml, $parameters)
case "rqzh-norm.odd" return pm-rqzh-norm-web:transform($xml, $parameters)
    default return pm-rqzh-web:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:print-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "rqzh.odd" return pm-rqzh-print:transform($xml, $parameters)
case "rqzh-norm.odd" return pm-rqzh-norm-print:transform($xml, $parameters)
    default return pm-rqzh-print:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:latex-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "rqzh.odd" return pm-rqzh-latex:transform($xml, $parameters)
case "rqzh-norm.odd" return pm-rqzh-norm-latex:transform($xml, $parameters)
    default return pm-rqzh-latex:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:epub-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "rqzh.odd" return pm-rqzh-epub:transform($xml, $parameters)
case "rqzh-norm.odd" return pm-rqzh-norm-epub:transform($xml, $parameters)
    default return pm-rqzh-epub:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:tei-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "docx.odd" return pm-docx-tei:transform($xml, $parameters)
    default return error(QName("http://www.tei-c.org/tei-simple/pm-config", "error"), "No default ODD found for output mode tei")
            
    
};
            
    