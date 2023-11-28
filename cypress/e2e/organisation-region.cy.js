describe('place-list page for ZH_NF_I_1_11', () => {
    beforeEach('loads', () => {
        cy.visit('organization/ZH_NF_I_1_11/')
    })


    // it('the city is Basel', () => {
    //     cy.get('#locations pb-geolocation')
    //     .should('be.visible')
    //     .contains('Basel (Stadt)')
    // })

    it('The place is ZH_NF_I_1_11', () => {
        cy.get('pb-split-list .organization')
        .should('be.visible')
        .should('have.length', 4)
    })

 
})