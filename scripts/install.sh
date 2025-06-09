rm -rf sourcemap.json Packages && 
wally install && 
rojo sourcemap default.project.json >> sourcemap.json && 
wally-package-types Packages --sourcemap sourcemap.json 