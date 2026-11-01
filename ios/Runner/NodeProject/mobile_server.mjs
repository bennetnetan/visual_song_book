import http from 'node:http';
import { convertAccessFile } from './tools/convert_vsb_to_vsbook.mjs';

const server = http.createServer(async (request, response) => {
  response.setHeader('Content-Type', 'application/json');
  if (request.method === 'GET' && request.url === '/health') {
    response.writeHead(200).end(JSON.stringify({ ready: true }));
    return;
  }
  if (request.method !== 'POST' || request.url !== '/convert') {
    response.writeHead(404).end(JSON.stringify({ error: 'Not found' }));
    return;
  }
  try {
    let body = '';
    for await (const chunk of request) body += chunk;
    const { inputPath, outputPath } = JSON.parse(body);
    if (typeof inputPath !== 'string' || typeof outputPath !== 'string') {
      throw new Error('Input and output paths are required.');
    }
    await convertAccessFile(inputPath, outputPath);
    response.writeHead(200).end(JSON.stringify({ outputPath }));
  } catch (error) {
    response.writeHead(400).end(JSON.stringify({ error: error.message ?? String(error) }));
  }
});

server.listen(39873, 'localhost');
