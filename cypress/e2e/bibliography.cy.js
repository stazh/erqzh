describe('Bibliography page multilingual tests', () => {
    const translations = require('../fixtures/translations-bibliography.json')
    Object.keys(translations).forEach((lang) => {
        describe(`Language: ${lang}`, () => {

            // Load the page and set the language before each test
            beforeEach(function () {
                const texts = translations[lang];
                cy.visit('literaturverzeichnis.html', {
                    onBeforeLoad(win) {
                        Object.defineProperty(win.navigator, 'languages', { value: [lang] });
                    }
                });
                this.texts = texts;
            });

            // Metadata tests
            it('checks meta title', function () {
                cy.title()
                    .should('not.be.empty')
                    .should('contain', this.texts.metaTitle);
            });

            it('checks meta description', function () {
                cy.get('meta[name="description"]')
                    .should('have.attr', 'content')
                    .and('not.be.empty');
            });

            // Content tests
            it('checks h1 header', function () {
                cy.contains('h1', this.texts.h1).should('be.visible');
            });

            it.skip('checks footer', function () {
                cy.get('.footer__imprint').should('be.visible');
            });

            it('checks app header', function () {
                cy.get('app-header').should('be.visible');
            });

        });

    });

});


describe('Bibliography page language-independent tests', () => {
    beforeEach('should load', () => {
        cy.visit('literaturverzeichnis.html')
    })

    it('should display two separate tables', () => {
        cy.get('table')
            .should('be.visible')
            .should('have.length', 2)
    })

    // see https://gitlab.existsolutions.com/rqzh/rqzh2/-/issues/83#note_19302
    it('should only have 3 columns', () => {
        cy.get('thead > tr >th')
            .should('be.visible')
            .should('have.length', 6)
    })

    // see https://gitlab.existsolutions.com/rqzh/rqzh2/-/issues/83#note_19473
    it('should not truncate page numbers in journal articels', () => {
        cy.get('tr#chbsg000045808')
            .contains('Bickel, Wolf-H.')
            .contains('195–217')
    })

    // ensure fixup was applied
    it('should not truncate page numbers in journal articels', () => {
        cy.get('tr#chbsg000105140')
            .contains('Rippmann, Dorothee')
            .contains('91–114')
    })
})

