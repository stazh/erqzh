describe('place-list page', () => {
    beforeEach('loads', () => {
        cy.visit('places/all/')
    })

    it('displays a map', () => {
        cy.get('.pb-container > #map').should('be.visible')
    })

    it('displays app searchbar', () => {
        cy.get('#query').should('be.visible')
    })
})