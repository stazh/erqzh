document.addEventListener('DOMContentLoaded', function () {
    const searchParams1 = new URLSearchParams(new URL(window.location.href).search);
    document.querySelector('[name=type]').value = searchParams1.get("type")

    pbEvents.subscribe('pb-login', null, function(ev) {
        if (ev.detail.userChanged) {
            pbEvents.emit('pb-search-resubmit', 'search');
        }
    });

    pbEvents.subscribe('pb-start-update', 'search', function() {
        console.log('hiding');
        document.querySelector('main').classList.toggle('faded');
    });

    /* Parse the content received from the server */
    pbEvents.subscribe('pb-results-received', 'search', function(ev) {
        const { content } = ev.detail;
        console.log(ev.detail);
        document.querySelector('main').classList.toggle('faded');

        /* Check if the server passed an element containing the current 
           collection in attribute data-root */
        const root = content.querySelector('[data-root]');
        const currentCollection = root ? root.getAttribute('data-root') : "";
        const writable = root ? root.classList.contains('writable') : false;
        
        /* Report the current collection and if it is writable.
           This is relevant for e.g. the pb-upload component */
        pbEvents.emit('pb-collection', 'search', {
            writable,
            collection: currentCollection
        });
        /* hide any element on the page which has attribute can-write */
        document.querySelectorAll('[can-write]').forEach((elem) => {
            elem.disabled = !writable;
        });

        /* Scan for links to collections and handle clicks */
        content.querySelectorAll('[data-collection]').forEach((link) => {
            link.addEventListener('click', (ev) => {
                ev.preventDefault();

                const collection = link.getAttribute('data-collection');
                // write the collection into a hidden input and resubmit the search
                document.querySelector('.options [name=collection]').value = collection;
                pbEvents.emit('pb-search-resubmit', 'search');
            });
        });

        document.querySelector('[name=date-min]').value = null;
        document.querySelector('[name=date-max]').value = null;
    });

    const facets = document.querySelector('.facets');
    if (facets) {
        facets.addEventListener('pb-custom-form-loaded', function(ev) {
            const elems = ev.detail.querySelectorAll('.facet');
            elems.forEach(facet => {
                facet.addEventListener('change', () => {
                    if (!facet.checked) {
                        pbRegistry.state[facet.name] = null;
                    }
                    const table = facet.closest('table');
                    if (table) {
                        const nested = table.querySelectorAll('.nested .facet').forEach(nested => {
                            if (nested != facet) {
                                nested.checked = false;
                            }
                        });
                    }
                    pbEvents.emit('pb-search-resubmit', 'search');
                });
            });
            ev.detail.querySelectorAll('pb-combo-box').forEach((select) => {
                select.renderFunction = (data, escape) => {
                    if (data) {
                        return `<div>${escape(data.text)} <span class="freq">${escape(data.freq || '')}</span></div>`;
                    }
                    return '';
                }
            });
            ev.detail.querySelectorAll('.dropdown').forEach((select) => {
                select.addEventListener('change',() => {
                    pbEvents.emit('pb-search-resubmit', 'search');
                })
            });
        });

        pbEvents.subscribe('pb-combo-box-change', null, function() {
            pbEvents.emit('pb-search-resubmit', 'search');
        });
    }

    const volumes = document.querySelector('#volumes');
    if (volumes) {
        volumes.addEventListener('pb-custom-form-loaded', function(ev) {
            ev.detail.querySelectorAll('[name=facet-volume]').forEach((select) => {
                select.addEventListener('change',() => {
                    pbEvents.emit('pb-search-resubmit', 'search');
                })
            });
        });
    }





    const timeRangeStart = document.getElementById('period-start');
    const timeRangeEnd = document.getElementById('period-end');

    const timelineChanged = (ev) => {
        let categories = ev.detail.categories;
        if (ev.detail.scope === '5Y') {
            expandDates(categories, 5);
        } else if (ev.detail.scope === '10Y') {
            expandDates(categories, 10);
        }

        document.querySelectorAll('[name=dates]').forEach(input => { input.value = categories.join(';') });
        const startEnd = ev.detail.label.split(/\s*–\s*/);
        timeRangeStart.value = startEnd[0];
        timeRangeEnd.value = startEnd[1];
        pbEvents.emit('pb-search-resubmit', 'search');
    };
    pbEvents.subscribe('pb-timeline-date-changed', 'timeline', timelineChanged);
    pbEvents.subscribe('pb-timeline-daterange-changed', 'timeline', timelineChanged);
    pbEvents.subscribe('pb-timeline-reset-selection', 'timeline', () => {
        document.querySelectorAll('[name=dates]').forEach(input => { input.value = '' });
        pbEvents.emit('pb-search-resubmit', 'search');
    });
    pbEvents.subscribe('pb-timeline-loaded', 'timeline', (ev) => {
        const startEnd = ev.detail.label.split(/\s+–\s+/);
        timeRangeStart.value = startEnd[0];
        if (startEnd.length === 2) {
            timeRangeEnd.value = startEnd[1];
        } else {
            timeRangeEnd.value = null;
        }
    });

    document.getElementById('period-submit').addEventListener('click', () => {
        let start = timeRangeStart.value;
        let end = timeRangeEnd.value;

        document.querySelector('[name=date-min]').value = start;
        document.querySelector('[name=date-max]').value = end;
        document.querySelectorAll('[name=dates]').forEach(input => { input.value = '' });

        pbEvents.emit('pb-search-resubmit', 'search');
    });

    document.querySelector('[name=sort]').addEventListener('change', () => {
        pbEvents.emit('pb-search-resubmit', 'search');
    });

    /**
   * Retrieve search parameters from URL
   */
    function getUrlParameter(sParam) {
        let urlParams = new URLSearchParams(window.location.search);
        return urlParams.getAll(sParam);
    }

    // search options: handle genre checkboxes
    const bearbeitungstext = document.getElementById("bearbeitungstext");
    let submit = false;

    function checkRequiredSubtypes() {
        // at least one Bearbeitungstext subtype is selected
        if (document.querySelector(".bearbeitungstext[checked]")) {
            return;
        }
        document.getElementById('editionstext').checked = true;
    }

    if (bearbeitungstext) {
        const checkboxes = document.querySelectorAll(".bearbeitungstext");
        // click on Bearbeitungstext selects/deselects all subtypes
        bearbeitungstext.addEventListener("click", () => {
            submit = false;
            checkboxes.forEach((item) => {
                item.checked = bearbeitungstext.checked;
            });
            checkRequiredSubtypes();
            pbEvents.emit('pb-search-resubmit', 'search');
            submit = true;
        });

        // initialize checkboxes from URL
        const subtypes = getUrlParameter('subtype');
        if (subtypes && subtypes.length > 0) {
            subtypes.forEach((subtype) => {
                document.querySelector(`paper-checkbox[value=${subtype}]`).checked = true;
            });
            bearbeitungstext.checked = !document.querySelector(".bearbeitungstext:not([checked])");
            document.getElementById('editionstext').checked = subtypes.includes('edition');
        } else {
            // no subtypes in URL: enable all checkboxes
            bearbeitungstext.checked = true;
            document.getElementById('editionstext').checked = true;
            checkboxes.forEach((item) => {
                item.checked = true;
            });
        }
        checkRequiredSubtypes();
        submit = true;

        // for each subtype we need to enable/disable the broader Bearbeitungstext checkbox
        checkboxes.forEach((item) => {
            item.addEventListener("iron-change", (ev) => {
                if (submit) {
                    checkRequiredSubtypes();
                    if (document.querySelector(".bearbeitungstext:not([checked])")) {
                        bearbeitungstext.checked = false;
                    } else {
                        bearbeitungstext.checked = true;
                    }
                    pbEvents.emit('pb-search-resubmit', 'search');
                }
            });
        });
        document.getElementById('editionstext').addEventListener('click', () => {
            if (!document.querySelector(".bearbeitungstext[checked]")) {
                document.getElementById('editionstext').checked = true;
                return;
            }
            if (submit) {
                pbEvents.emit('pb-search-resubmit', 'search');
            }
        });
    }
});


function expandDates(categories, n) {
    categories.forEach((category) => {
        const year = parseInt(category);
        for (let i = 1; i < n; i++) {
            categories.push(year + i);
        }
    });
}

