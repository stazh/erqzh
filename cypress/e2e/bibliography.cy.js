describe('people page', () => {
    it('loads', () => {
        cy.visit('literaturverzeichnis.html')
    })

    it('displays two separate tables', () => {
        cy.get('caption')
        .should('be.visible')
        .should('have.length', 2)
    })
})

