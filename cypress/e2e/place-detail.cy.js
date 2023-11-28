describe('place-detail page', () => {
    beforeEach('loads', () => {
        cy.visit('places/all/Basel?key=loc000161')
    })

    it('displays a map', () => {
        cy.get('.pb-container #map').should('be.visible')
    })

    it('the city is Basel', () => {
        cy.get('#locations pb-geolocation')
        .should('be.visible')
        .contains('Basel (Stadt)')
    })

 
})