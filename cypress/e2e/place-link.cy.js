describe('place-list page for ZH_NF_I_1_11', () => {
    beforeEach('loads', () => {
        cy.visit('places/ZH_NF_I_1_11/')
    })

    it('The place list is visible', () => {
        cy.get('pb-split-list .place')
        .should('be.visible')
    })
    
    it('visual aspects of link – name', () => {
        cy.get('pb-split-list .place')
        .should('have.css', 'font-size', '16px')
        .contains('a')
        .should('contain', 'A')
        .should('have.css', 'color', 'rgb(0, 118, 189)')
    })

    it('visual aspects of link – type', () => {
        cy.get('span .type')
        .should('contain', '(')
        .should('contain', ')')
    })

    it.only('visual aspects of link – type inside .place has brackets', () => {
        cy.wait(2000)
        cy.get('pb-split-list .place')
        .get('.type')
        .should('contain', '(')
        .should('contain', ')')
    })

    it('Aesch is Aesch', () => {
        cy.get('pb-split-list > .place a')
        .contains('Aesch')
        .should('be.visible')
        .invoke('attr', 'href')
        .should('eq', 'Aesch?&category=A&search=&key=loc010352')
    })


 
})