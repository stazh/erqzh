xquery version "3.1";

import module namespace batch="http://existsolutions.com/rqzsh/batch" at "batch.xql";
import module namespace scraper="http://existsolutions.com/rqzsh/scraper" at "scraper.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.expath.exist.HttpClientModule";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(: generate id lists to scrape only batches :)
(:batch:main():)
 
(: PLACES :)
(:scraper:download-places():)
(:scraper:generate-places():)
(:scraper:places-all(10):)
(:scraper:places-add-geo-data():)
(:scraper:generate-places-xml-for-col():)
(:scraper:get-duplicate-places():)

(:  PERSONS :)
(: scraper:persons-all(10):)
(:scraper:generate-persons():)
(:batch:generate-and-store-person-id-batches(10):)
(: for $number in 290 to 329:)
(:    return:)
(:        scraper:download-persons-batch-number($number):)
(:(:scraper:download-persons-batch-from(282):):)
(:scraper:download-persons-batch-number(285):)
 scraper:generate-person-xml-for-col()

(:scraper:analyze-json-batches():)
(: let $errors := scraper:analyze-json-batches():)
(: return:)
(:     string-join($errors[@category="organization"]//error/text(),","):)

(:scraper:analyze-register-data():)

(: TAXONOMIES  :)
 
(:scraper:taxonomy-all(10):)
(: scraper:generate-taxonomies():)

(: ORGANIZATION :) 
(:scraper:organizations-all(10):)
(: scraper:generate-organizations():)
(:scraper:generate-organizations-xml-for-col():)
 
(:  ERROR HANDLING  :)
(:scraper:rescraper-errors():)

(:  CODE BITS :)
(:collection("/db/apps/rqzh-data/temp/place")//info[@id="loc013730"]:)
(:return:)
(:    for $t in $tmp :)
(:    return util:document-name($t):)
 