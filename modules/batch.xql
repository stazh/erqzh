xquery version "3.1";

module namespace batch="http://existsolutions.com/rqzsh/batch";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $batch:ITEMS-PER-BATCH-DEFAULT := 10;

declare function batch:main() {
    if(not(xmldb:collection-available($config:temp-root)))
    then(
        xmldb:create-collection($config:data-root, "temp")
    )
    else(),
    
    batch:generate-and-store-key-id-batches($batch:ITEMS-PER-BATCH-DEFAULT),
    batch:generate-and-store-organization-id-batches($batch:ITEMS-PER-BATCH-DEFAULT),
    batch:generate-and-store-person-id-batches($batch:ITEMS-PER-BATCH-DEFAULT),
    batch:generate-and-store-place-id-batches($batch:ITEMS-PER-BATCH-DEFAULT)
};

declare function batch:generate-and-store-key-id-batches($items-per-batch) {
    let $content := element ids { batch:get-key-ids($items-per-batch) }
    (: Store the data as an xml file into the data collection for further post-processing :)
    return
        xmldb:store($config:temp-root, $config:key-id-file-name, $content )
};

(:~
 : Retrieve all key Ids from current collection(s)
 : and split the data into a comma separated,
 : small batches for better post-processing
 :)
declare function batch:get-key-ids($items-per-sequence) {
    let $sorted-key-ids :=
        for $key-id in collection($config:data-root)//tei:term[starts-with(@ref, 'key')]
            group by $key-id
            order by $key-id
                return
                    $key-id/@ref/string()
    
    return
        batch:generate-entry(distinct-values($sorted-key-ids), $items-per-sequence)
};


declare function batch:generate-and-store-organization-id-batches($items-per-batch) {
    let $content := element ids { batch:get-organization-ids($items-per-batch) }
    
    (: Store the data as an xml file into the data collection for further post-processing :)
    return
        xmldb:store($config:temp-root, $config:organization-id-file-name, $content )
};

(:~
 : Retrieve all organization Ids from current collection(s)
 : and split the data into a comma separated,
 : small batches for better post-processing
 :)
declare function batch:get-organization-ids($items-per-sequence) {
    let $sorted-organization-ids := 
        for $organization-id in collection($config:data-root)//tei:orgName/@ref
            group by $organization-id
            order by $organization-id
                return
                    $organization-id/string()
    
    return
        batch:generate-entry(distinct-values($sorted-organization-ids), $items-per-sequence)
};

declare function batch:generate-and-store-person-id-batches($items-per-batch) {
    let $content := element ids { batch:get-person-ids($items-per-batch) }
    
    (: Store the data as an xml file into the data collection for further post-processing :)
    return
        xmldb:store($config:temp-root, $config:person-id-file-name, $content )
};

(:~
 : Retrieve all person Ids from current collection(s)
 : and split the data into a comma separated,
 : small batches for better post-processing
 :)
declare function batch:get-person-ids($items-per-sequence) {
    let $unsorted-person-ids := (
        collection($config:data-root)//tei:persName/@ref/string(),
        collection($config:data-root)//@scribe[starts-with(., 'per')]/string()
    )
    
    let $sorted-person-ids :=
        for $person-id in $unsorted-person-ids
            group by $person-id
            order by $person-id
                return
                    $person-id[1]
    
    return
        batch:generate-entry($sorted-person-ids, $items-per-sequence)
};

declare function batch:generate-and-store-place-id-batches($items-per-batch) {
    let $content := element ids { batch:get-place-ids($items-per-batch) }
    (: Store the data as an xml file into the data collection for further post-processing :)
    return
        xmldb:store($config:temp-root, $config:place-id-file-name, $content )
};

(:~
 : Retrieve all location Ids from current collection(s)
 : and split the data into a comma separated,
 : small batches for better post-processing
 :)
declare function batch:get-place-ids($items-per-sequence) {
    let $sorted-location-ids :=
        for $location-id in collection($config:data-root)//(tei:placeName[@ref]|tei:origPlace[@ref])
            return
                    $location-id/@ref/string()
    
    return
       batch:generate-entry(distinct-values($sorted-location-ids), $items-per-sequence)
};

declare function batch:generate-entry($sorted-ids, $items-per-sequence){
    for $item at $pos in $sorted-ids
        return (
            if ($pos mod $items-per-sequence = 1)
            then (
                element row {
                    string-join(
                        for $item in subsequence($sorted-ids, $pos, $items-per-sequence)
                            return $item,
                        ","
                    )
                }
            )
            else ()
        )
};
