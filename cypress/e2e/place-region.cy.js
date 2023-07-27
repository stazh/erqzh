describe('place-list page for ZH_NF_I_1_11', () => {
    beforeEach('loads', () => {
        cy.visit('places/ZH_NF_I_1_11/')
    })

    it('displays a map', () => {
        cy.get('.pb-container #map').should('be.visible')
    })

    // it('the city is Basel', () => {
    //     cy.get('#locations pb-geolocation')
    //     .should('be.visible')
    //     .contains('Basel (Stadt)')
    // })

    it('The place is ZH_NF_I_1_11', () => {
        cy.get('pb-split-list .place')
        .should('be.visible')
    })

 
})