xquery version "3.1";

(:~ This library runs the XQSuite unit tests for the <%- title %> app.
 :
 : @author Duncan Paterson
 : @version 2.10.1
 : @see http://www.exist-db.org/exist/apps/doc/xqsuite
 :)
import module namespace test = "http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace tests = "http://jinntec.de/ssrq/tests" at "transform_bibl_spec.xqm";
import module namespace a-spec = "http://jinntec.de/ssrq/a-spec" at "app_spec.xqm";


declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "json";
declare option output:media-type "application/json";


(:~
 : transform_bibl_spec will error on an updated bibliography, it is needed for the transformation
 :)
test:suite(
  (
    inspect:module-functions(xs:anyURI("app_spec.xqm")),
    (: inspect:module-functions(xs:anyURI("transform_bibl_spec.xqm")) :)
  )
)