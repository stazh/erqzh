describe('landing page', () => {
  it('loads', () => {
    cy.visit('index.html')
  })

  it('displays app header', () => {
    cy.get('app-header')
      .should('be.visible')
  })

  it('displays feature image', () => {
    cy.get('img').should('be.visible')
  })

  it('displays app footer', () => {
    cy.get('.footer__imprint').should('be.visible')
  })
})