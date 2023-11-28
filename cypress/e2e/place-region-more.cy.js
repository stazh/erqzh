describe('place-list page for ZH_NF_I_1_11', () => {
    beforeEach('loads', () => {
        cy.visit('places/ZH_NF_I_1_11/')
    })

    it('displays a map', () => {
        cy.get('.pb-container #map').should('be.visible')
    })
    
    it('List of places is visible', () => {
        cy.get('pb-split-list .place')
        .should('be.visible')
    })

    it('display headline', () => {
        cy.contains('h1', 'Places')
    })

    it('display Albis', () => {
        cy.contains('a', 'Albis')
        .should('have.attr', 'href', 'Affoltern am Albis?&category=A&search=&key=loc011161')
    })

    // rather unnesary test closer to unit test then integration
    it('test each A place for containing name and category in href', () => {    
        cy.get('.place a')
        .should('have.length', 16)
        .each(($place, index, $lis) => {
            const text = $place.text() + "?&category=A"
            const href = cy.wrap($place).invoke('attr', 'href')
            cy.wrap($place).invoke('attr', 'href').should('include', text)

            
        })
        // .then(($lis) => {
        // expect($lis).to.have.length(16) // true
        // })

    })


    // it('Search for “an”', () => { // works and then start to fail
    //     cy.get('[name="search"]').first().focus()
    //     .type('an')
    //     cy.get('#query > [role=button]').click()
        
    //     cy.get('.place')
    //     .should('have.length', 3)
    //     // .and('contain', 'Andelfingen')
    //     .contains('a', 'Andelfingen')

    //     // cy.get('.place').should('have.length', 3)
    //     cy.get('.place').its('length').should('be.gte', 0)
      
    //     console.clear()
    //     console.log('AAAAAAA')
    //     console.log(cy.get('.place').should('have.length', 3))
    //     // .should('have.length', 3)
    //   })

      it('Search for “an” with shadow', () => {     
        cy.root()
        cy.get('[name="search"]').first().focus()
        // .wait(1000)
        .type('an', {force:true}) 
        // It forced to type because the element is in shadow DOM
        // see https://github.com/cypress-io/cypress/issues/7741
        cy.get('#query > [role=button]').click()
        
        cy.get('.place')
        .should('have.length', 3)
        // // .and('contain', 'Andelfingen')
        .contains('a', 'Andelfingen')

        // cy.get('.place').should('have.length', 3)
        cy.get('.place').its('length').should('be.gte', 0)       
        
      })
 
      //How to get to shadow
      // cy.get('#input-1').shadow()

      //write to the console
      // console.clear()
      // console.log('AAAAAAAAAAAAA')
      // const text = $place.text() + "?&category=A"
      // console.log(text, href)
})