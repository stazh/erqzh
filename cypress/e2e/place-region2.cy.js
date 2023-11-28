// ZH_NF_I_1_3 does not work, so test will fail
describe('place-list page for ZH_NF_I_1_3', () => {
    beforeEach('loads', () => {
        cy.visit('places/ZH_NF_I_1_3/')
    })

    it('displays a map', () => {
        cy.get('.pb-container #map').should('be.visible')
    })

    // it('the city is Basel', () => {
    //     cy.get('#locations pb-geolocation')
    //     .should('be.visible')
    //     .contains('Basel (Stadt)')
    // })

    it('The place is ZH_NF_I_1_3', () => {
        cy.get('pb-split-list .place')
        .should('be.visible')
    })

 
})