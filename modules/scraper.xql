xquery version "3.1";

module namespace scraper="http://existsolutions.com/rqzsh/scraper";

import module namespace batch="http://existsolutions.com/rqzsh/batch" at "batch.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.expath.exist.HttpClientModule";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $scraper:KEY_URL_PART := "https://www.ssrq-sds-fds.ch/lemma-db-edit/views/get-key-infos.xq";
declare variable $scraper:PLACES_URL_PART := "https://www.ssrq-sds-fds.ch/places-db-edit/views/get-infos.xq";
declare variable $scraper:persons-db := "https://www.ssrq-sds-fds.ch/persons-db-api/";

declare variable $scraper:organization := "organization";
declare variable $scraper:taxonomy := "taxonomy";
declare variable $scraper:place := "place";
declare variable $scraper:person := "person";

declare variable $scraper:blacklist := ("per001535", "per013523", "per014195", "per023953","per024601","per026014","per026513", "per026513", "per027014", "per027107","per027180","per027178","per027183", "per027341","per027408","per027478","per027477","per027566","per027567","per028081","per027587","per0275921","per028140", "per028188","per028914","per028982","per029333","per029464","per027623","per027670","per027671");


declare variable $scraper:json-serialization-options := 
    map{
        "method": "json",
        "indent": true()
    };

(: SCRAPE IT ALL AND GENERATE NEW REGISTERS :)
declare function scraper:all() {
    scraper:organizations-all($batch:ITEMS-PER-BATCH-DEFAULT),
    scraper:places-all($batch:ITEMS-PER-BATCH-DEFAULT),
    scraper:persons-all($batch:ITEMS-PER-BATCH-DEFAULT),
    scraper:taxonomy-all($batch:ITEMS-PER-BATCH-DEFAULT)
};
declare function scraper:analyze-json-batches() {
(:    scraper:analyze-json($scraper:person), :)
    scraper:analyze-json($scraper:organization)
};

declare function scraper:rescraper-errors-alt() {
    (: PERSONS :)
    let $person-data := for $error in scraper:analyze-json($scraper:person)//batch-errors[error/@code = 'httperror']
        return (
            util:log("info","http error in " || $error/@file),
            let $index as xs:integer := xs:integer($error/error/@row/string())[1]
            let $ids := doc($config:temp-root || '/' || $config:person-id-file-name)//row[$index]/text()
            let $json-persons := 
                for $id in tokenize($ids,",")
                    return
                        let $scrape := scraper:request-json($id)
                        return
                            map {
                                "error":$scrape?error[1],
                                "info":$scrape?info[1]
                            }
            let $errors := serialize( $json-persons?error, $scraper:json-serialization-options)                 
            let $log := util:log("info", "errors: " || $errors)
            let $info := serialize( $json-persons?info, $scraper:json-serialization-options)                 
            
            
            let $json-data := parse-json('
                                {
                                    "error" : ' || $errors || ',
                                    "info" : ' || $info ||'
                                }')
                return
                    scraper:store-json($scraper:person, $index, $json-data)
        )
    return
        $person-data
    
            
(:    scraper:analyze-json($scraper:organization):)
};

declare function scraper:analyze-json($category) {
    let $batch-errors := for $batch in xmldb:get-child-resources($config:temp-root || "/" || $category)
        let $json := parse-json(util:binary-to-string(util:binary-doc($config:temp-root || "/" || $category || "/" || $batch )))
        return (
            if(array:size($json?error) > 0)
            then (
                let $batch-file := $config:temp-root || "/" || $category || "/" || $batch
                let $row as xs:integer := xs:integer(substring-before(substring-after($batch, "batch-"), ".json"))
                let $log := util:log("info", "found " || array:size($json?error) || " error(s) in " || $batch-file)
                let $errors := array:for-each($json?error, function($error) {
                                    switch($error?error)
                                        case "notfound" return 
                                            element error {
                                                attribute code {"notfound"},
                                                $error?id
                                            }
                                        case "httperror" return 
                                            element error {
                                                attribute code { "httperror"},
                                                attribute row { $row } ,
                                                attribute ids { $json?ids } ,
                                                attribute http-status { $json?http-status }
                                            }
                                        default return 
                                            element error {"unknown error " || $error?error }
                                    
                                })
                return
                    <batch-errors file="{$batch-file}">
                        {$errors}
                    </batch-errors>
                    
            ) else ()
        )
    let $sorted-errors := for $error in $batch-errors
                            order by $error/@file
                            return 
                                $error
    return
        <errors category="{$category}">
            {$sorted-errors}
        </errors>
        
};

(:  ORGANIZATION :)
declare function scraper:organizations-all($ids-per-batch) {
    util:log("info", "scraper:organisation-all: started" ),    
    batch:generate-and-store-organization-id-batches($ids-per-batch),
    scraper:download-organizations(),
    scraper:generate-organizations(),
    util:log("info", "scraper:organisation-all: ended" )
};

declare function scraper:download-organizations() {
    let $prepare := scraper:prepare-scraper-run($scraper:organization)
    return
        for $row at $index in doc($config:temp-root || '/' || $config:organization-id-file-name)//row
            return
                scraper:process-batch-json($scraper:organization, $row, $index)
};

declare function scraper:generate-organizations() {
    let $resources := xmldb:get-child-resources($config:temp-root || "/" || $scraper:organization)
    let $organizations := for $batch in $resources
                        let $json := parse-json(util:binary-to-string(util:binary-doc($config:temp-root || "/" || $scraper:organization || "/" || $batch )))
                        return (
                            if(array:size($json?error) > 0)
                            then (
(:                                util:log("error", "error in json file " || $batch),:)
                                array:for-each($json?error, function($error) {
                                    util:log("error", "id " || $error?id || " not found")                                        
                                })
                            ) 
                            else (),
                            for $info in $json?info?*
                                return
                                    scraper:conv-organization($info)
                        )
    let $organization-tei := 
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="organizations" type="Organization">
            { scraper:tei-header($scraper:organization) }
            <standOff>
                <listOrg> 
                    { $organizations }
                </listOrg>
            </standOff>
        </TEI>
    return
        xmldb:store($config:data-root || "/" || $scraper:organization, $scraper:organization || ".xml", $organization-tei)
};

declare function scraper:conv-organization($info) {
    <org xmlns="http://www.tei-c.org/ns/1.0" xml:id="{ $info?id }" type="{$info?type}">
        <orgName>{ $info?name }</orgName>
    </org>
};

(:  TAXONOMY :)
declare function scraper:taxonomy-all($ids-per-batch) {
    util:log("info", "scraper:taxonomy-all: started" ),    
    batch:generate-and-store-key-id-batches($ids-per-batch),
    scraper:download-taxonomies(),
    scraper:generate-taxonomies(),
    util:log("info", "scraper:taxonomy-all: ended" )
    
};

declare function scraper:download-taxonomies() {
    let $prepare := scraper:prepare-scraper-run($scraper:taxonomy)
    let $rows := doc($config:temp-root || '/' || $config:key-id-file-name)//row
    return
        for $row at $index in $rows
            let $download-taxonomy := scraper:request-xml($row, $scraper:KEY_URL_PART)
            return
                xmldb:store( $config:temp-root || "/" || $scraper:taxonomy,  'batch-' || $index || '.xml', $download-taxonomy )
};

declare function scraper:generate-taxonomies() {
    let $infos := collection($config:temp-root || "/" || $scraper:taxonomy)//info[@id]
    let $log := util:log("info", "scraper:generate-taxonomies: generating " || count($infos) || " tei taxonomies")
    let $tei-taxonomies :=
        for $info in $infos
            order by $info/name
            return
                if(string-length($info/name) > 0)
                then ( scraper:conv-taxonomy($info) ) 
                else ( 
                    util:log("ERROR", "Taxonomy/@id " || $info/@id || " has an empty name element.")    
                )
    let $output :=
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <teiHeader>
                <fileDesc>
                    <titleStmt><title>Example taxonomy for TEI Publisher demo files</title></titleStmt>
                    <publicationStmt><p/></publicationStmt>
                    <sourceDesc><p/></sourceDesc>
                </fileDesc>
                <encodingDesc>
                    <classDecl>
                        <taxonomy xml:id="pb-taxonomy">
                            { $tei-taxonomies }
                        </taxonomy>
                    </classDecl>
                </encodingDesc>
            </teiHeader>
        </TEI>
    return
        xmldb:store($config:data-root || "/" || $scraper:taxonomy, $scraper:taxonomy || ".xml", $output)
};

declare function scraper:conv-taxonomy($info) {
    let $id := $info/@id/string()
    let $desc := $info/name/text()
    let $gloss := $info/definition/text()
    
    return
        <category xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}">
            <desc xml:lang="deu">{$desc }</desc>
            <gloss>{ $gloss }</gloss>
        </category>

};

declare function scraper:persons-all($ids-per-batch) {
    util:log("info", "scraper:persons-all: started" ),    
    batch:generate-and-store-person-id-batches($ids-per-batch),
    scraper:download-persons(),
    scraper:generate-persons(),
    util:log("info", "scraper:persons-all: ended" )
};

declare function scraper:download-persons() {
    let $prepare := scraper:prepare-scraper-run($scraper:person)
    return
        for $batch at $index in doc($config:temp-root || '/' || $config:person-id-file-name)//row
            return
                scraper:process-batch-json($scraper:person, $batch, $index)
};
declare function scraper:download-persons-batch-number($batch as xs:integer*) {
    for $number in $batch 
        return
            scraper:download-persons-batch-from-to($number,$number)
};

declare function scraper:download-persons-batch-from($start as xs:integer) {
    scraper:download-persons-batch-from-to($start, ())
};
declare function scraper:download-persons-batch-from-to($start as xs:integer, $end as xs:integer?) {
    let $rows := doc($config:temp-root || '/' || $config:person-id-file-name)//row
    let $last := if($end) then ($end) else (count($rows))
    return
        for $batch at $index in $rows
            return
                if($index >= $start and $index <= $last)
                then (
                    scraper:process-batch-json($scraper:person, $batch, $index)
                ) else ()

};

declare function scraper:generate-persons() {
    let $resources := xmldb:get-child-resources($config:temp-root || "/" || $scraper:person)
    let $persons := for $batch in $resources
                        let $json := parse-json(util:binary-to-string(util:binary-doc($config:temp-root || "/" || $scraper:person || "/" || $batch )))
                        return
                            if(array:size($json?error) = 0)
                            then (
                                for $person in $json?info?*
                                    return
                                        scraper:conv-person($person)
                                    
                            ) else (
                                util:log("error", $json)    
                            )
    let $persons-tei := 
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="persons" type="Person">
            { scraper:tei-header($scraper:person) },
            <standOff>
                <listPerson> 
                    { $persons }
                </listPerson>
            </standOff>
        </TEI>
    return
        xmldb:store($config:data-root || "/" || $scraper:person, $scraper:person || ".xml", $persons-tei)
};
declare function scraper:conv-person($person) {
    let $persName := $person?name
    let $note := $person?dates
    return
        <person xmlns="http://www.tei-c.org/ns/1.0" xml:id="{ $person?id }">
            <persName type="full">{ $persName }</persName>
            <note type="date">{ $note }</note>            
        </person>
};

declare function scraper:places-all($ids-per-batch) {
    util:log("info", "scraper:places-all: started" ),    
    batch:generate-and-store-place-id-batches($ids-per-batch),
    scraper:download-places(),
    scraper:generate-places(),
    util:log("info", "scraper:places-all: ended")
};

declare function scraper:download-places() {
    let $prepare := scraper:prepare-scraper-run($scraper:place)
    let $rows := doc($config:temp-root || '/' || $config:place-id-file-name)//row
    return
        for $row at $index in $rows
            let $download-places := scraper:request-xml($row, $scraper:PLACES_URL_PART)
            return
                xmldb:store( $config:temp-root || "/" || $scraper:place,  'batch-' || $index || '.xml', $download-places )
};

declare function scraper:generate-places() {
    let $info-places := collection($config:temp-root || "/" || $scraper:place)//info[@id]
    let $log := util:log("info", "scraper:generate-places: generating " || count($info-places) || " tei places")
    let $tei-places :=
        for $info in $info-places
            order by $info/stdName
            return
                if(string-length($info/stdName) > 0)
                then ( scraper:conv-place($info) ) 
                else ( 
                    util:log("ERROR", "Plaece/@id " || $info/@id || " has an empty stdName element.")    
                )
    let $output :=
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="places" type="Ort">
            {  scraper:tei-header($scraper:place) },
            <standOff>
                <listPlace>
                    { $tei-places }
                </listPlace>
            </standOff>
        </TEI>
    return
        xmldb:store($config:data-root || "/" || $scraper:place, $scraper:place || ".xml", $output)
};

declare function scraper:conv-place($info){
    let $id := $info/@id
    let $short-name := $info/stdName/text()
    let $location := 
        if(string-length( $info/location/text() ) > 0 ) 
        then ( "(" || $info/location/text() || ")" ) else ()
    let $types := string-join($info/type/text(), ", ")
    let $long-name := $location || " " || $types 
    let $regions := for $region in $info/region
                        return
                            <region xmlns="http://www.tei-c.org/ns/1.0">{$region/text()}</region>
    
    let $trait-types := for $type in $info/type
                    return
                        <trait xmlns="http://www.tei-c.org/ns/1.0" type="type"><label>{$type/text()}</label></trait>
                                       
(:    let $log := util:log("info", "id: " || $id || " - name: " || $placeName):)
    return
        <place xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}" n="{$short-name}">
               <placeName type="main">{$short-name}</placeName>
               <placeName type="add">{$long-name}</placeName>
               {$regions}
               {$trait-types}
               <location>
                    <geo></geo>
                </location>
        </place>
};


(: GENERAL SCRAPER FUNCTIONS :)

(: delete data from previous runs :)
declare function scraper:prepare-scraper-run($col-name) {
    let $col-uri := $config:temp-root || "/" || $col-name
    let $create-col := if(xmldb:collection-available($col-uri))
                        then( xmldb:remove($col-uri) )
                        else ()
    return
        xmldb:create-collection($config:temp-root, $col-name)
};

(: STORE JSON RETURNED FOR SINGLE BATCH  :)
declare function scraper:store-json($category, $index, $json-data){
    xmldb:store( 
        $config:temp-root || "/" || $category,  
        'batch-' || $index || '.json', 
        serialize( $json-data, $scraper:json-serialization-options) 
    )    
};

(: SCRAPER BATCH AND STORE RESULT JSON  :)
declare function scraper:process-batch-json($category, $batch, $index) {
    util:log("info", "scraping " || $category || " at index " || $index ),
    scraper:store-json(
        $category, 
        $index, 
        scraper:request-json($batch) 
    )
};

(: REQUEST RETURN JSON :)
declare function scraper:request-json($ids) {
let $log := util:log("info", "scraper:request-json: ids: " || $ids)    
let $valid-ids := string-join(
                    for $id in tokenize($ids, ",")
                        return
                            if(contains($scraper:blacklist,$id))
                            then ()
                            else $id
                    , ",")
let $log := util:log("info", "scraper:request-json: valid ids: " || $valid-ids)    
let $request := <http:request method="GET" href="{$scraper:persons-db}mai/?ids_search={ $valid-ids }"/>
let $response := http:send-request($request)
    return (
        if ($response[1]/@status = "200") then (
(:            let $log := util:log("info", "scraper:request-json: response status = 200 ")    :)
            parse-json(util:binary-to-string($response[2]))
        ) else
            (
                util:log("error", "scraper:request-json: response status:" || $response[1]/@status || " - first id is: " || $ids[1]),
                (:                util:log("error",  $response):)
                parse-json('{ 
                    "error" : [{"error" : "httperror"}],
                    "http-status": "' || $response[1]/@status ||'",
                    "ids" : "' || string-join($valid-ids,",") ||'" 
                }')
            )
        )
};

(: REQUEST RETURN XML :)
declare function scraper:request-xml($ids, $url-part) {
(:    let $log := util:log("info", "scraper:request-xml: ids: " || $ids)    :)
    let $request := <http:request method="GET" href="{ $url-part }?id={ $ids }"/>
    let $response := http:send-request($request)
        return (
            if ($response[1]/@status = "200") then
(:                let $log := util:log("info", "scraper:request-json: response status = 200 ")    :)
                let $xml := $response[2]
                return (
                    $xml/infos
                )
            else
                (
                    util:log("error", "scraper:request-xml: response status:" || $response[1]/@status),
                    util:log("error",  $response)
                )
            )
};

declare function scraper:tei-header($category) {
    let $title := switch($category)
                    case $scraper:person return "Personendaten"
                    case $scraper:organization return "Organisationsdaten"
                    case $scraper:place return "Ortsdaten"
                    default return ""
    return
        <teiHeader xmlns="http://www.tei-c.org/ns/1.0">
            <fileDesc>
                <titleStmt>
                    <title>Rechtsquellen des Kantons Zürich: {$title}</title>
                </titleStmt>
                <publicationStmt>
                    <p>Publication Information</p>
                </publicationStmt>
                <sourceDesc><p>Information about the source</p></sourceDesc>
            </fileDesc>
        </teiHeader>
};
