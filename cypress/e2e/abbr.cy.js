describe('abbreviation page', () => {
    it('loads', () => {
        cy.visit('abbr.html')
    })

    it('displays symbols', () => {
        // TODO: see #93 this doesn't properly test 
        // the computed css used by various browsers but its a start
        cy.get(':nth-child(4) > :nth-child(3)')
        .should('be.visible')
        .and('have.css', 'font')
        .and('match', /Lexia Fontes/)    
    })
})