import assert from 'node:assert/strict';
import { Client as ModernClient } from '@modelcontextprotocol/client';
import { StdioClientTransport as ModernTransport } from '@modelcontextprotocol/client/stdio';
import { Client as LegacyClient } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport as LegacyTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
const executable = process.argv[2];
for (const [label, Client, Transport, options] of [
  ['legacy SDK 1.26.0', LegacyClient, LegacyTransport, {capabilities:{}}],
  ['modern SDK 2.4.0 pinned', ModernClient, ModernTransport, {capabilities:{}, versionNegotiation:{mode:{pin:'2026-07-28'}}}],
  ['modern SDK 2.4.0 auto', ModernClient, ModernTransport, {capabilities:{}, versionNegotiation:{mode:'auto'}}]
]) {
 const client = new Client({name:'MacHandle synthetic compatibility test',version:'1'}, options);
 const transport = new Transport({command:executable,args:['--synthetic'],stderr:'pipe'});
 let stderr='';
 transport.stderr?.on('data', bytes => { stderr+=bytes.toString(); });
 try {
  await client.connect(transport);
  const list = await client.listTools();
  assert.deepEqual(list.tools.map(t=>t.name), ['mock_add','mock_fail','mock_status','mock_wait']);
  const sum = await client.callTool({name:'mock_add',arguments:{a:17,b:25}});
  assert.equal(sum.isError,false); assert.equal(sum.structuredContent.sum,42);
  const fail = await client.callTool({name:'mock_fail',arguments:{}});
  assert.equal(fail.isError,true);
  assert.equal(stderr,'');
  console.log(label+': discovery/initialization, schemas, calls, tool errors passed');
 } finally { await client.close(); }
}
