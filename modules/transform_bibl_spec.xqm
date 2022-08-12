xquery version "3.1";

(:~ This library module contains XQSuite tests for the bibliography transformation script.
 :
 : @author Duncan Paterson
 : @version 2.10.1
 :)

module namespace tests = "http://jinntec.de/ssrq/tests";
import module namespace t-bibl = "http://jinntec.de/ssrq/t_bibl" at "transform_bibl.xqm";

declare namespace test="http://exist-db.org/xquery/xqsuite";
declare default element namespace "http://www.tei-c.org/ns/1.0";


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
        <imprint>
            <biblScope unit="volume">39</biblScope>
        </imprint>
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
    %test:name('item-chbsg991001259148103977')
    %test:args('chbsg991001259148103977')
    %test:assertTrue 
    function tests:diss-note-s1($item-id) {
       let $result := t-bibl:transform-list($t-bibl:bibl//id($item-id))
       let $test := 
<biblStruct xmlns="http://www.tei-c.org/ns/1.0" xml:id="chbsg991001259148103977" type="W"><!-- Thesis -->
    <monogr><!-- author origin: MARC 100 -->
        <author>Heidinger, Hermann</author>
        <title type="full">Die Lebensmittel-Politik der Stadt Zürich im Mittelalter</title>
        <title type="short">Heidinger 1910</title>
        <note>Diss.</note>
        <imprint><!-- publisher origin: MARC 260 -->
            <publisher>Buchdr. der Ipf- und Jagst-Zeitung</publisher><!-- pubPlace origin: MARC 260 -->
            <pubPlace>Ellwangen</pubPlace><!-- date origin: MARC 260 -->
            <date>1910</date>
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
    <monogr type="edition"><!-- author origin: MARC 700 -->
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