const rows = new Map();
function queryConcat(sql) { return rows.get(sql) || []; }
function queryParam(sql, params) { return rows.get(sql + JSON.stringify(params)) || []; }
module.exports = { queryConcat, queryParam };
