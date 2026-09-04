const http = require('http');
const invoices = require('./invoices');
const PORT = process.env.PORT || 8080;
const server = http.createServer((req, res) => {
  const [, root, id] = req.url.split('/');
  if (root !== 'invoices') { res.writeHead(404); return res.end('{"error":"not found"}'); }
  if (id) { res.writeHead(200, {'content-type':'application/json'});
            return res.end(JSON.stringify(invoices.findById(id))); }
  res.writeHead(405); res.end('{"error":"method not allowed"}');
});
if (require.main === module) server.listen(PORT);
module.exports = server;
