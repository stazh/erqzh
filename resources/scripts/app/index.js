window.addEventListener("DOMContentLoaded", () => {
    const facets = document.getElementById('options');
    const timeRangeLabel = document.getElementById('time-range');
    const timelineChanged = (ev) => {
        let categories = ev.detail.categories;
        if (ev.detail.scope === '5Y') {
            expandDates(categories, 5);
        } else if (ev.detail.scope === '10Y') {
            expandDates(categories, 10);
        }
        document.querySelectorAll('[name=dates]').forEach(input => { input.value = categories.join(';') });
        facets.submit();

        timeRangeLabel.innerHTML = ev.detail.label === '' ? 'alles' : ev.detail.label;
    };
    pbEvents.subscribe('pb-timeline-date-changed', 'timeline', timelineChanged);
    pbEvents.subscribe('pb-timeline-daterange-changed', 'timeline', timelineChanged);
    pbEvents.subscribe('pb-timeline-reset-selection', 'timeline', () => {
        document.querySelectorAll('[name=dates]').forEach(input => { input.value = '' });
        timeRangeLabel.innerHTML = 'alles';
        facets.submit();
    });
    pbEvents.subscribe('pb-timeline-loaded', 'timeline', (ev) => {
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
