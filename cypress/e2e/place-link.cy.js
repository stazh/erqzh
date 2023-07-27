describe('place-list page for ZH_NF_I_1_11', () => {
    beforeEach('loads', () => {
        cy.visit('places/ZH_NF_I_1_11/')
    })

    // it('displays a map', () => {
    //     cy.get('.pb-container #map').should('be.visible')
    // })


    // it('The place is ZH_NF_I_1_11', () => {
    //     cy.get('pb-split-list .place')
    //     .should('be.visible')
    // })

    it('Aesch is Aesch', () => {
        cy.get('pb-split-list > .place a')
        .contains('Aesch')
        .should('be.visible')
        .invoke('attr', 'href')
        .should('eq', 'Aesch?&category=A&search=&key=loc010352')
    })

    // it('America is America', () => {
    //     cy.get('pb-split-list > .place a')
    //     .contains('Aesch')
    //     .should('be.visible')
    //     .invoke('attr', 'href')
    //     .should('eq', 'Aesch?&category=A&search=&key=loc010352')
    // })

 
})