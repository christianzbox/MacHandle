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
  assert.deepEqual(list.tools.map(t=>t.name), ['get_availability', 'get_calendar_event', 'get_reminder', 'list_calendars', 'list_reminder_lists', 'mock_add', 'mock_fail', 'mock_status', 'mock_wait', 'search_calendar_events', 'search_reminders']);
  const sum = await client.callTool({name:'mock_add',arguments:{a:17,b:25}});
  assert.equal(sum.isError,false); assert.equal(sum.structuredContent.sum,42);
  const fail = await client.callTool({name:'mock_fail',arguments:{}});
  assert.equal(fail.isError,true);
  const calendars = await client.callTool({name:'list_calendars',arguments:{}});
  assert.equal(calendars.isError,false);
  assert.equal(calendars.structuredContent.calendars.length,1);
  const calendarId = calendars.structuredContent.calendars[0].calendarId;
  const window = {calendarIds:[calendarId],startMs:1799999000000,endMs:1800004000000};
  const availability = await client.callTool({name:'get_availability',arguments:window});
  assert.equal(availability.isError,false);
  assert.equal(availability.structuredContent.absenceProvesFree,false);
  const search = await client.callTool({name:'search_calendar_events',arguments:{...window,query:'planning',fields:['title'],limit:10}});
  assert.equal(search.isError,false);
  assert.equal(search.structuredContent.events.length,1);
  const eventId = search.structuredContent.events[0].eventId;
  const detail = await client.callTool({name:'get_calendar_event',arguments:{eventId,fields:['location']}});
  assert.equal(detail.isError,false);
  assert.equal(detail.structuredContent.status,'found');
  assert.deepEqual(Object.keys(detail.structuredContent.event.fields),['location']);
  const denied = await client.callTool({name:'get_calendar_event',arguments:{eventId,fields:['notes']}});
  assert.equal(denied.isError,true);
  for (const value of [calendars,availability,search,detail,denied]) {
    assert(!JSON.stringify(value).includes('private'));
    assert(!JSON.stringify(value).includes('synthetic-hidden-note-canary'));
  }
  const lists = await client.callTool({name:'list_reminder_lists',arguments:{}});
  assert.equal(lists.isError,false);
  const listId = lists.structuredContent.lists[0].listId;
  const reminders = await client.callTool({name:'search_reminders',arguments:{listIds:[listId],query:'grocery',fields:['title','due','recurrence'],limit:10}});
  assert.equal(reminders.isError,false);
  assert.equal(reminders.structuredContent.reminders.length,1);
  const reminderId = reminders.structuredContent.reminders[0].reminderId;
  const reminder = await client.callTool({name:'get_reminder',arguments:{reminderId,fields:['completion']}});
  assert.equal(reminder.structuredContent.status,'found');
  assert.deepEqual(Object.keys(reminder.structuredContent.reminder.fields),['completion']);
  const hiddenNotes = await client.callTool({name:'get_reminder',arguments:{reminderId,fields:['notes']}});
  assert.equal(hiddenNotes.isError,true);
  for (const value of [lists,reminders,reminder,hiddenNotes]) {
    assert(!JSON.stringify(value).includes('private'));
    assert(!JSON.stringify(value).includes('synthetic-hidden-reminder-canary'));
  }
  assert.equal(stderr,'');
  console.log(label+': discovery/initialization, schemas, mock/calendar/reminder reads, privacy, tool errors passed');
 } finally { await client.close(); }
}
