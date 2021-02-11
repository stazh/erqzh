# RQZH2 Readme


## Build rqzh2
* simply run the command `ant` in your terminal in the rqzh2 folder
  
## Utilise Dev Version of pb-components

1. clone tei-publisher-components ( github.com/eeditiones/tei-publisher-components/ )
1. in rqzh2 modules/config.xqm set $config:webcomponents-cdn to ‘local’ 
1. call `ant xar-local`
1. remove tei-publisher-components from resources/scripts ( `rm -rf resources/scripts/*.js` )
1. in tei-publisher-components repo execute `npm run build` 
1. copy generated .js and .map files from the tei-publisher-components ( e.g. `cp dist/*.js dist/*.map $RQZH/rqzh2/resources/scripts/` )
1. call `ant xar-local` again

## Run pb-components from feature branch

1. configure the branch / PR in `package.json` like this `"@teipublisher/pb-components": "git+https://github.com/eeditiones/tei-publisher-components.git#develop"` 
1. in modules/config.xqm set `config:webcomponents` to `local`
2. call `ant clean xar-local`

## Use local dev version of pb-components

1. clone tei-publisher-components ( github.com/eeditiones/tei-publisher-components/ ) or use
your existing clone
1. in rqzh2 modules/config.xqm set `$config:webcomponents :="dev"`;
1. in rqzh2 modules/config.xqm set `$config:webcomponents-cdn` to ‘http://localhost:8000’ (default port)
1. run `npm i` to load dependencies
1. run 'npm run start' to start the devserver which by default listens on port 8000
1. wait until server is running and start eXist-db with rqzh2 