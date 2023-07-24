document.addEventListener('DOMContentLoaded', function () {
    pbEvents.subscribe('pb-login', null, function(ev) {
        if (ev.detail.userChanged) {
            pbEvents.emit('pb-search-resubmit', 'search');
        }
    });

    /* Parse the content received from the server */
    pbEvents.subscribe('pb-results-received', 'search', function(ev) {
        const { content } = ev.detail;
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
        });

        pbEvents.subscribe('pb-combo-box-change', null, function() {
            pbEvents.emit('pb-search-resubmit', 'search');
        });
    }

    const timeRangeLabel = document.getElementById('time-range');
    const timelineChanged = (ev) => {
        let categories = ev.detail.categories;
        if (ev.detail.scope === '5Y') {
            expandDates(categories, 5);
        } else if (ev.detail.scope === '10Y') {
            expandDates(categories, 10);
        }
        document.querySelectorAll('[name=dates]').forEach(input => { input.value = categories.join(';') });
        pbEvents.emit('pb-search-resubmit', 'search');

        timeRangeLabel.innerHTML = ev.detail.label === '' ? 'alles' : ev.detail.label;
    };
    pbEvents.subscribe('pb-timeline-date-changed', 'timeline', timelineChanged);
    pbEvents.subscribe('pb-timeline-daterange-changed', 'timeline', timelineChanged);
    pbEvents.subscribe('pb-timeline-reset-selection', 'timeline', () => {
        document.querySelectorAll('[name=dates]').forEach(input => { input.value = '' });
        timeRangeLabel.innerHTML = 'alles';
        pbEvents.emit('pb-search-resubmit', 'search');
    });
    pbEvents.subscribe('pb-timeline-loaded', 'timeline', (ev) => {
        console.log("pb-timeline-loaded ", ev.detail.label);
        timeRangeLabel.innerHTML = ev.detail.label === '' ? 'alles' : ev.detail.label;
    });

    // pbEvents.subscribe('pb-collection', 'docs', (ev) => {
    //     const timeline = document.querySelector('.timeline');
    //     if (!ev.detail.collection) {
    //         timeline.style.display = 'none';
    //     } else {
    //         timeline.style.display = 'block';
    //     }
    // });    
});


function expandDates(categories, n) {
    categories.forEach((category) => {
        const year = parseInt(category);
        for (let i = 1; i < n; i++) {
            categories.push(year + i);
        }
    });
}

