window.addEventListener("DOMContentLoaded", () => {
  const register = document.getElementById("register");
  let blocks = [];

  pbEvents.subscribe("pb-start-update", ["transcription", "metadata"], () => {
    register.innerHTML = 'Lade ...';
    if (blocks.length === 2) {
      blocks = [];
    }
  });

  // wait for the transcription and metadata pb-view to update and remember its content root
  pbEvents.subscribe("pb-update", "transcription", (ev) => {
    document.body.setAttribute(
      "data-view",
      ev.detail.data.odd === "rqzh-norm.odd" ? "normalized" : "diplomatic"
    );
    blocks.push(ev.detail.root);
    if (blocks.length === 2) {
      register.load();
    }
  });
  pbEvents.subscribe("pb-update", "metadata", (ev) => {
    const credits = ev.detail.root.querySelector("#credits");
    const creditsTarget = document.getElementById("credits");
    if (credits && creditsTarget) {
      creditsTarget.innerHTML = credits.innerHTML;
    }
    blocks.push(ev.detail.root);
    if (blocks.length === 2) {
      register.load();
    }
  });

  // find popovers containing the id in their data-ref attribute and call the callback for each.
  function findPopovers(id, callback) {
    blocks.forEach((content) => {
      content.querySelectorAll("pb-popover[data-ref]").forEach((popover) => {
        // data-ref contains a space-separated list of refs
        // each may have a suffix, so we have to match against the start of the substring
        const re = new RegExp(`(^|\\s+)${id}`);
        if (re.test(popover.getAttribute("data-ref"))) {
          callback(popover);
        }
      });
    });
  }

  function find(selector, callback) {
    blocks.forEach((content) => {
      content.querySelectorAll(selector).forEach(callback);
      content.querySelectorAll("template").forEach((template) => {
        template.content.querySelectorAll(selector).forEach(callback);
      });
    });
  }

  // wait until register content has been loaded, then walk trough the transcription
  // and extend all persName, placeName etc. popovers with the additional information
  pbEvents.subscribe("pb-end-update", "register", (ev) => {
    document.querySelectorAll(".register li[data-ref]").forEach((li) => {
      const id = li.getAttribute("data-ref");
      findPopovers(id, (ref) => {
        // is it a popover?
        if (ref.alternate) {
          // check if it is a nested popover: target will be in one of the list items
          const inList = ref.alternate.querySelector(`li[data-ref^="${id}"]`);
          if (inList) {
            inList.appendChild(document.createTextNode(li.textContent));
          } else {
            ref.alternate.appendChild(document.createTextNode(li.textContent));
          }
        } else {
          ref.appendChild(document.createTextNode(li.textContent));
        }
        // click on reference should open database entry in new tab
        ref.addEventListener("click", () => {
          li.querySelector("div a").click();
        });
      });
      // scribes are handled separately:
      find(`.scribe[data-ref^="${id}"]`, function (span) {
        span.innerHTML = li.textContent;
      });

      const checkbox = li.querySelector("paper-checkbox");
      checkbox.addEventListener("change", () => {
        findPopovers(id, (ref) => {
          if (checkbox.checked) {
            ref.classList.add("highlight");
            const collapse = ref.closest("pb-collapse");
            if (collapse) {
              collapse.open();
            }
          } else {
            ref.classList.remove("highlight");
          }
        });
      });
    });
  });

  /**
   * Retrieve search parameters from URL
   */
  function getUrlParameter(sParam) {
    let urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(sParam);
  }

  /**
   * Retrieve current parameter value of language filter
   */
  function getLanguageFilters() {
    let languageFilterValue = getUrlParameter('filter-language');
    return languageFilterValue.toString();
  }

  /**
   * Check for active language filter params in URL and check the according checkboxes
   */
  document.querySelectorAll(".filter-language-input").forEach((item) => {
    let languagesSelected = getLanguageFilters();
    if (languagesSelected.includes(item.value)) {
      item.setAttribute("checked", "checked");
    }
  });

  const bearbeitungstext = document.getElementById("bearbeitungstext");
  if (bearbeitungstext) {
    bearbeitungstext.addEventListener("iron-change", (ev) => {
      document.querySelectorAll(".bearbeitungstext").forEach((item) => {
        item.checked = ev.target.checked;
      });
    });
  }

  document.querySelectorAll(".bearbeitungstext").forEach((item) => {
    // console.log("item: ", item);
    item.setAttribute("checked", "checked");
  });

  const sortSelect = document.getElementById("sort-select");
  if (sortSelect) {
    sortSelect.addEventListener("iron-select", (ev) => {
      // console.log("sort-select iron-select event: ", ev);
      var newSortValue = ev.detail.item.getAttribute("value");
      // console.log("sort results by:", newSortValue);
      var hiddenSort = document.querySelector("#hiddenSort");
      var oldSortValue = hiddenSort.getAttribute("value");
      // console.log("oldSortValue: ", oldSortValue);
      if (newSortValue != oldSortValue) {
        // console.log("apply new sort criteria: ", newSortValue);
        hiddenSort.setAttribute("value", newSortValue);
        document.querySelector("#search-form")._doSearch();
      }
    });
  }

  const openPrintDialog = document.getElementById("openPrintDialog");
  openPrintDialog.addEventListener("click", () => {
    let currentOrigin = window.location.origin.toString();
    let currentPath = window.location.pathname.toString();
    let docPath = currentPath.replace(/^.*\/([^/]+\/.*)$/, "$1");
    let urlPart = currentPath.replace(/^(.*)\/[^/]+\/.*$/, "$1");
    let updatedDocPath = docPath.replace("/", "%2F");
    let newUrl = `${urlPart}/api/document/${updatedDocPath}/html?odd=rqzh-norm.odd`;
    console.log(newUrl);
    window.open(newUrl);
  });

  /**
   * Get the current status of pb-facsimile (loaded or not)
   * and apply the appropriate grid class to the wrapping element "gridWrapper"
   * If the facsimile has not been loaded, display the register in the sidebar as grid item.
   */
  window.addEventListener("load", () => {
    const gridWrapper = document.getElementById("gridWrapper");
    window.pbEvents.subscribe("pb-facsimile-status", null, (ev) => {
      //console.log('facsimile status', ev.detail.status);
      if (ev.detail.status === "loaded") {
        gridWrapper.setAttribute(
          "class",
          "document-grid document-grid__facsimile"
        );
      } else {
        gridWrapper.setAttribute(
          "class",
          "document-grid document-grid__register"
        );
      }
    });
  });
});
