describe('bibliography page', () => {
    it('should load', () => {
        cy.visit('literaturverzeichnis.html')
    })

    it('should display two separate tables', () => {
        cy.get('caption')
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

