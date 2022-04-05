xquery version "3.1";

import module namespace batch="http://existsolutions.com/rqzsh/batch" at "batch.xql";
import module namespace scraper="http://existsolutions.com/rqzsh/scraper" at "scraper.xql";

(: generate id lists to scrape only batches :)
(:batch:main():)
 
(: PLACES :)
(:scraper:download-places():)
(:scraper:generate-places():)
(:scraper:places-all(10):)

(:  PERSONS :)
(: scraper:persons-all(10):)
(:scraper:generate-persons():)
(:batch:generate-and-store-person-id-batches(10):)
(: for $number in 290 to 329:)
(:    return:)
(:        scraper:download-persons-batch-number($number):)
(:(:scraper:download-persons-batch-from(282):):)
(:scraper:download-persons-batch-number(285):)

(:scraper:analyze-json-batches():)
 let $errors := scraper:analyze-json-batches()
 return
     string-join($errors[@category="organization"]//error/text(),",")


(: TAXONOMIES  :)
 
(:scraper:taxonomy-all(10):)
(: scraper:generate-taxonomies():)

(: ORGANIZATION :) 
(:scraper:organizations-all(10):)
(: scraper:generate-organizations():)
 
(:  ERROR HANDLING  :)
(:scraper:rescraper-errors():)

(:  CODE BITS :)
(:collection("/db/apps/rqzh-data/temp/place")//info[@id="loc013730"]:)
(:return:)
(:    for $t in $tmp :)
(:    return util:document-name($t):)
 