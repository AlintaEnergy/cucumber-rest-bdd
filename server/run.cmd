copy db.json testdb.json
json-server testdb.json -m error.js -r routes.json
del testdb.json