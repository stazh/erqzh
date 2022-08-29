xquery version "3.1";

(:~ This library module contains XQSuite tests for the bibliography transformation script.
 : Since the input fails to validate the transformation attempts to correct most mistakes.
 : 
 :
 : @author Duncan Paterson
 : @version 2.10.1
 :)

module namespace tests = "http://jinntec.de/ssrq/tests";
import module namespace t-bibl = "http://jinntec.de/ssrq/t_bibl" at "transform_bibl.xqm";

declare namespace test="http://exist-db.org/xquery/xqsuite";
declare namespace validation="http://exist-db.org/xquery/validation";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare default element namespace "http://www.tei-c.org/ns/1.0";

declare variable $tests:test-name := 'SSRQ_test';

(:used in validation tests below:)
declare variable $tests:mini-header := 
   <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Title</title>
         </titleStmt>
         <publicationStmt>
            <p>Publication Information</p>
         </publicationStmt>
         <sourceDesc>
            <p>Information about the source</p>
         </sourceDesc>
      </fileDesc>
   </teiHeader>;
   

(: jing as trouble with accessing the schema via URI directly so local it is :)
declare variable $tests:schema-uri := xs:anyURI('http://www.tei-c.org/release/xml/tei/custom/schema/relaxng/tei_all.rng');
declare variable $tests:schema-2 := doc('tei_all-2.rng');

declare 
    %test:setUp
    function tests:store-and-fix(){
            t-bibl:store-result($t-bibl:bibl, $tests:test-name),
            t-bibl:fixup-series-dates(doc('../data/' || $tests:test-name || '.xml')),
            t-bibl:fixup-monogr-dates(doc('../data/' || $tests:test-name || '.xml'))
    };

declare 
    %test:tearDown
    function tests:cleanup() {
        xmldb:remove('../data/', $tests:test-name || '.xml')
    };

(: scope 1 :)
declare
    %test:name('item-chbsg000138187')
    %test:args('chbsg000138187')
    %test:assertEquals(1)
    function tests:detect-scope1($item-id) {
        let $result := $t-bibl:bibl//id($item-id) ! t-bibl:analyze-scope(.//biblScope)
        
        return
             count($result/*)
        
}; 
 
declare
    %test:name('page-filter')
    %test:assertTrue
    function tests:detect-s.() {
        let $in := t-bibl:scope-1('S. 77–123')
        let $match := <biblScope unit='page'>77–123</biblScope>
        return
            deep-equal($in, $match)
        
};

declare
    %test:name('item-chbsg000135549')
    %test:args('chbsg000135549')
    %test:assertEquals('NF 279')
    function tests:detect-scope1-nf($item-id) {
        let $result := $t-bibl:bibl//id($item-id) ! t-bibl:analyze-scope(.//biblScope)
        
        return
             $result//*[@unit="volume"]/text() 
        
}; 

(: scope 2 :)
declare
    %test:name('item-chbsg000151121')
    %test:args('chbsg000151121')
    %test:assertEquals(2)
    function tests:detect-scope2($item-id) {
        let $result := $t-bibl:bibl//id($item-id) ! t-bibl:analyze-scope(.//biblScope)
        
        return
             count($result/*)
        
};  

(: scope 3 :)
declare
    %test:name('item-chbsg000138125')
    %test:args('chbsg000138125')
    %test:assertEquals(3) 
    function tests:detect-scope3($item-id) {
        let $result := $t-bibl:bibl//id($item-id) ! t-bibl:analyze-scope(.//biblScope)
        
        return
             count($result/*)
        
};  

(:~ broken Bickel 2006
 : @see https://gitlab.existsolutions.com/rqzh/rqzh2/-/issues/83#note_19476
 :)
declare
    %test:name('item-chbsg000045808')
    %test:args('chbsg000045808')
    %test:assertEquals(3) 
    function tests:scope-bickel($item-id) {
        let $result := $t-bibl:bibl//id($item-id) ! t-bibl:analyze-scope(.//biblScope)
        
        return
             count($result/*)
        
};

 
 
(: scope 4 :)
declare
    %test:name('item-chbsg000137082')
    %test:args('chbsg000137082')
    %test:assertEquals(1) 
    function tests:detect-scope3n($item-id) {
        let $result := $t-bibl:bibl//id($item-id) ! t-bibl:analyze-scope(.//biblScope)
        
        return
             count($result/*)
        
}; 

(:~ working Hauser 1912a 
 : @see https://gitlab.existsolutions.com/rqzh/rqzh2/-/issues/83#note_19477
 :)
declare
    %test:name('item-chbsg000137379')
    %test:args('chbsg000137379')
    %test:assertEquals(1) 
    function tests:scope-hauser($item-id) {
        let $result := $t-bibl:bibl//id($item-id) ! t-bibl:analyze-scope(.//biblScope)
        
        return
             count($result/*)
};

(: transform :)
declare
    %test:name('item-chbsg000137914')
    %test:args('chbsg000137914')
    %test:assertTrue 
    function tests:monogr-series-volume-s1($item-id) {
       let $result := t-bibl:transform-list($t-bibl:bibl//id($item-id))
       let $test := 
<biblStruct xmlns="http://www.tei-c.org/ns/1.0" xml:id="chbsg000137914" type="W"><!-- Monographie -->
    <monogr><!-- author origin: MARC 100 -->
        <author>Hauser, Kaspar</author>
        <title type="full">Das Sondersiechenhaus zu St. Georg bei Winterthur 1287–1828</title>
        <title type="short">Hauser 1901</title>
        <imprint><!-- imprint origin: MARC 260 -->
            <publisher>Geschw. Ziegler</publisher>
            <pubPlace>Winterthur</pubPlace><!-- date origin: MARC 260 -->
            <date>1901</date>
        </imprint>
    </monogr>
    <series><!-- series origin: MARC 830 -->
        <title>Neujahrsblatt der Hülfsgesellschaft von Winterthur</title>
        <biblScope unit="volume">39</biblScope>
    </series>
</biblStruct>

       return
           deep-equal($result, $test)
};

declare
    %test:name('item-chbsg000135362')
    %test:args('chbsg000135362')
    %test:assertTrue 
    function tests:JA-s3-range($item-id) {
       let $result := t-bibl:transform-list($t-bibl:bibl//id($item-id))
       let $test := 
<biblStruct xmlns="http://www.tei-c.org/ns/1.0" xml:id="chbsg000135362" type="JA"><!-- Artikel in einer Zeitschrift -->
    <analytic><!-- author origin: MARC 100 -->
        <author>Hauser, Kaspar</author>
        <title type="full">Der Spital in Winterthur – 1300–1530</title>
        <title type="short">Hauser 1912</title>
    </analytic>
    <monogr>
        <title>Jahrbuch für schweizerische Geschichte</title>
        <imprint>
            <biblScope unit="issue">37</biblScope>
            <date>1912</date>
            <biblScope unit="page">55–154</biblScope>
        </imprint>
    </monogr>
</biblStruct>

       return
           deep-equal($result, $test)
};

declare
    %test:name('item-chbsg000091122')
    %test:args('chbsg000091122')
    %test:assertTrue 
    function tests:diss-note-s1($item-id) {
       let $result := t-bibl:transform-list($t-bibl:bibl//id($item-id))
       let $test := 
<biblStruct xmlns="http://www.tei-c.org/ns/1.0" xml:id="chbsg000091122" type="W"><!-- Thesis -->
    <monogr><!-- author origin: MARC 100 -->
        <author>Burghartz, Susanna</author>
        <title type="full">Leib, Ehre und Gut – Delinquenz in Zürich Ende des 14. Jahrhunderts</title>
        <title type="short">Burghartz 1990</title>
        <note>Diss.</note>
        <imprint><!-- imprint origin: MARC 260 -->
            <publisher>Chronos-Verlag</publisher>
            <pubPlace>Zürich</pubPlace><!-- date origin: MARC 260 -->
            <date>1990</date>
        </imprint>
    </monogr>
</biblStruct>

       return
           deep-equal($result, $test)
};

declare
    %test:name('item-chbsg000135610')
    %test:args('chbsg000135610')
    %test:assertTrue 
    function tests:monogr-type-edition($item-id) {
       let $result := t-bibl:transform-list($t-bibl:bibl//id($item-id))
       let $test := 
<biblStruct xmlns="http://www.tei-c.org/ns/1.0" xml:id="chbsg000135610" type="W"><!-- Selbständige Edition -->
    <monogr><!-- author origin: MARC 700 -->
        <author>Egli, Emil</author>
        <title type="full">Actensammlung zur Geschichte der Zürcher Reformation in den Jahren 1519–1533</title>
        <title type="short">Egli, Actensammlung</title>
        <imprint><!-- imprint origin: MARC 260 -->
            <publisher>Schabelitz</publisher>
            <pubPlace>Zürich</pubPlace><!-- date origin: MARC 260 -->
            <date>1879</date>
        </imprint>
    </monogr>
</biblStruct>

       return
           deep-equal($result, $test)
};

(: validate :)
(:~ helpter function to assemble result fragment into a full fledged tei document for validation testing :)
declare
    %private function tests:assemble-fragments($item-id)  {
        document { <TEI>
            { $tests:mini-header }
            <text>
                <body>
                    <p> tests </p>
                    <listBibl>
                    { t-bibl:transform-list($t-bibl:bibl//id($item-id)) }
                    </listBibl>
                </body>
            </text>    
        </TEI> }
    };


(: %test:assumeIntenetAccess('http://www.tei-c.org/release/xml/tei/custom/schema/relaxng/tei_all.rng') :)
declare
    %test:name('item-chbsg000068827')
    %test:args('chbsg000068827')
    %test:assertTrue 
    function tests:monogr-invalid-imprint($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
};
    
declare
    %test:name('item-chbsg000026120')
    %test:args('chbsg000026120')
    %test:assertTrue 
    function tests:ev-invalid-date($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
}; 

declare
    %test:name('item-chbsg000135610')
    %test:args('chbsg000135610')
    %test:assertTrue 
    function tests:work-valid($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
}; 



declare
    %test:name('item-chbsg991001180048503977')
    %test:args('chbsg991001180048503977')
    %test:assertTrue 
    function tests:ev-invalid-author($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
}; 

declare
    %test:name('item-chbsg000143225')
    %test:args('chbsg000143225')
    %test:assertTrue 
    function tests:ja-invalid-diss-note($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
};

declare
    %test:name('item-chbsg991001259148003977')
    %test:pending('fixup')
    %test:args('chbsg991001259148003977')
    %test:assertTrue 
    function tests:w-invalid-series-date-s1($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
};

declare
    %test:name('item-chbsg000055330')
    %test:args('chbsg000055330')
    %test:assertTrue 
    function tests:ja-inconsistent-date($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
};

declare
    %test:name('item-chbsg000135490')
    %test:pending('fixup')
    %test:args('chbsg000135490')
    %test:assertTrue 
    function tests:ev-bad-scope-date($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
};

declare
    %test:name('item-chbsg000105140')
    %test:pending('fixup')
    %test:args('chbsg000105140')
    %test:assertTrue 
    function tests:ja-invalid-date-s2($item-id) {
       let $result := tests:assemble-fragments($item-id)

       return
           validation:jing($result, $tests:schema-2)
};

(:~ header validation erros on exist-db make this fail, 
 : however the same file validates fine via oxygen
 : I am leaning towards exist's results as <date type="print"/> seems pretty non-sensical to me
 :)
declare
    %test:name('validate-fixed')
    %test:assertFalse
    function tests:invalid-fixed() {
       let $result := doc('../data/' || $tests:test-name || '.xml')

       return
           validation:jing($result, $tests:schema-2)
};