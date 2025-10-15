describe('Landing page multilingual tests', () => {
  const translations = require('../fixtures/translations-index.json')
  Object.keys(translations).forEach((lang) => {
    describe(`Language: ${lang}`, () => {

      // Load the page and set the language before each test
      beforeEach(function () {
        const texts = translations[lang];
        cy.visit('index.html', {
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

      it('checks footer', function () {
        cy.get('.footer__imprint').should('be.visible');
      });

      it('checks app header', function () {
        cy.get('app-header').should('be.visible');
      });

      it('displays feature image', () => {
        cy.get('img').should('be.visible')
      })

    });

  });

});

