describe('places page', () => {
    it('loads', () => {
        cy.visit('places.html')
    })

    it('displays a map', () => {
        cy.get('.pb-container > #map').should('be.visible')
    })

    it('displays app searchbar', () => {
        cy.get('#query').should('be.visible')
    })
})