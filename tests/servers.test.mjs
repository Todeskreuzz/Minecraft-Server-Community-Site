import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { cachedStatus, clearStatusCache, officialServer, readStatus, serverAddress, serverPort, serverTags, splitServers, statusUrl } from '../assets/js/forum-servers.mjs';

test('server fields stay inside the list rules', () => {
  assert.equal(serverAddress(' Play.Example.com '), 'play.example.com');
  assert.equal(serverPort(''), 25565);
  assert.equal(serverPort(25566), 25566);
  assert.deepEqual(serverTags('Forge, Survival, forge'), ['forge', 'survival']);
  assert.throws(() => serverAddress('https://play.example.com'), /Invalid address/);
  assert.throws(() => serverAddress('localhost'), /Invalid address/);
  assert.throws(() => serverPort(0), /Invalid port/);
  assert.throws(() => serverTags('n'), /Invalid tags/);
  assert.equal(statusUrl('play.example.com', 25565), 'https://api.mcsrvstat.us/3/play.example.com');
  assert.equal(statusUrl('play.example.com', 25566), 'https://api.mcsrvstat.us/3/play.example.com:25566');
  assert.deepEqual(readStatus({ online: true, players: { online: 3, max: 20 }, motd: { clean: ['Hallo', 'Welt'] } }), { online: true, players: '3 / 20', motd: 'Hallo Welt' });
  assert.equal(readStatus({ online: false }).online, false);
});

test('the official server leads the public list only when an address is configured', () => {
  assert.equal(officialServer({ server: { address: '' }, minecraftVersion: '1.20.1' }), null);
  const official = officialServer({ server: { address: 'play.example.com' }, minecraftVersion: '1.20.1' });
  const split = splitServers([
    { name: 'Geheim', is_public: false },
    { name: 'Lagerfeuer', is_public: true }
  ], { server: { address: 'play.example.com' }, minecraftVersion: '1.20.1' });
  assert.deepEqual(split.official, official);
  assert.deepEqual(split.publicRows.map(row => row.name), ['Lagerfeuer']);
  assert.deepEqual(split.privateRows.map(row => row.name), ['Geheim']);
  const html = fs.readFileSync(new URL('../index.html', import.meta.url), 'utf8');
  assert.match(html, /api\.mcsrvstat\.us/);
  assert.doesNotMatch(html, /aternos|minehut|falixnodes\.net\/api/i);
  const sql = fs.readFileSync(new URL('../supabase/migrations/20261025001200_servers.sql', import.meta.url), 'utf8');
  assert.match(sql, /community_servers/);
  assert.match(sql, /community-banners/);
  assert.doesNotMatch(sql, /drop table|truncate/i);
});

test('status lookups are cached for two minutes', async () => {
  clearStatusCache();
  let calls = 0;
  const fetcher = async () => {
    calls += 1;
    return new Response(JSON.stringify({ online: true, players: { online: 1, max: 8 }, motd: { clean: ['Hi'] } }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  };
  const first = await cachedStatus('play.example.com', 25565, fetcher, 1_000);
  const second = await cachedStatus('play.example.com', 25565, fetcher, 60_000);
  assert.equal(first.players, '1 / 8');
  assert.equal(second.motd, 'Hi');
  assert.equal(calls, 1);
  await cachedStatus('play.example.com', 25565, fetcher, 130_000);
  assert.equal(calls, 2);
});
