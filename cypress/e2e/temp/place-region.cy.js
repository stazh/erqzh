describe('place-list page for ZH_NF_I_1_11', () => {
    beforeEach('loads', () => {
        cy.visit('places/ZH_NF_I_1_11/')
    })

    it('displays a map', () => {
        cy.get('.pb-container #map').should('be.visible')
    })

    it('display headline', () => {
        cy.contains('h1', 'Places')
    })


    it('display Albis', () => {
        cy.contains('a', 'Albis')
        .should('have.attr', 'href', 'Affoltern am Albis?&category=A&search=&key=loc011161')
    })

    it('test each', () => {
        cy.get('pb-split-list .place').each(() => { //$el, index, $list
            // console.log($el, index, $list)
        }) 
    
    })

    it('test each A place', () => {    
        cy.get('.place a')
        .should('have.length', 16)
        .each(($place, index, $lis) => {
            const text = $place.text() + "?&category=A"
            const href = cy.wrap($place).invoke('attr', 'href')
            cy.wrap($place).invoke('attr', 'href').should('include', text)
            console.log('AAAAAAAAAAAAA')
            console.log(text, href)
            
        })
        // .then(($lis) => {
        // expect($lis).to.have.length(16) // true
        // })

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

    //does not work
    it('Search for “an”', () => {
        // cy.get('#input-1 > input')
        console.clear()
        console.log('Aaaaaa')
        console.log(cy.get('[name="search"]').first())
        cy.get('[name="search"]').first().focus()
        .type('an')
        cy.get('#query > [role=button]').click()
        
        cy.get('.place')
        .should('have.length', 3)
        
      })
 
})