describe('people page', () => {
    beforeEach('loads', () => {
        cy.visit('people/all/')
    })

    it('displays a searchbar', () => {
        cy.get('#query').should('be.visible')
    })

    it('displays list of people', () => {
        cy.get('pb-split-list').should('be.visible')
    })
})