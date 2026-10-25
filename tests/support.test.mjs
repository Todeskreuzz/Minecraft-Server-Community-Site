import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { bitcoinOk, ethereumChecksum, ethereumOk, keccak256, solanaOk, supportEntries } from '../assets/js/support.mjs';
import { qrMatrix } from '../assets/js/qr.mjs';

const BTC = 'bc1qvd4qdrtp6vp34y2tp5nntaxh8s7gdtcl6cleg0';
const ETH = '0x65Bc22A06395f366433FA9B79CD9E356d161f09B';
const SOL = 'EE34aTZx8UtMoEaLY5vJtkH1nLPkKyGVtZ3QMwBrfNPW';

function hex(bytes) {
  return [...bytes].map(byte => byte.toString(16).padStart(2, '0')).join('');
}

test('keccak256 is the Ethereum hash, and each configured address passes its checksum', () => {
  assert.equal(hex(keccak256(new Uint8Array())), 'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470');
  assert.equal(ethereumChecksum('0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed'), '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed');
  const config = JSON.parse(fs.readFileSync(new URL('../assets/data/config.json', import.meta.url), 'utf8'));
  assert.equal(config.support.crypto.bitcoin, BTC);
  assert.equal(config.support.crypto.ethereum, ETH);
  assert.equal(config.support.crypto.solana, SOL);
  assert.equal(bitcoinOk(BTC), true, 'bitcoin');
  assert.equal(ethereumOk(ETH), true, 'ethereum');
  assert.equal(solanaOk(SOL), true, 'solana');
  assert.equal(bitcoinOk('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'), false);
  assert.equal(bitcoinOk(BTC.slice(0, -1) + 'p'), false);
  assert.equal(ethereumOk(ETH.slice(0, -1) + 'c'), false);
  assert.equal(solanaOk('EE34'), false);
  assert.equal(solanaOk('0' + SOL.slice(1)), false);
  const entries = supportEntries(config);
  assert.deepEqual(entries.map(entry => entry.symbol), ['BTC', 'ETH', 'SOL']);
  assert.equal(entries.every(entry => entry.check(entry.address)), true);
});

test('local QR codes stay on version 3 and the page does not call a QR service', () => {
  for (const text of ['HELLO', BTC, ETH, SOL]) {
    const matrix = qrMatrix(text);
    assert.equal(matrix.length, 29);
    assert.equal(matrix.every(row => row.length === 29 && row.every(cell => cell === 0 || cell === 1)), true);
    assert.equal(matrix[0][0], 1);
    assert.equal(matrix[21][8], 1);
  }
  const html = fs.readFileSync(new URL('../index.html', import.meta.url), 'utf8');
  assert.match(html, /href="#support"/);
  assert.match(html, /data-i18n="support"/);
  assert.doesNotMatch(html, /qrserver|chart\.googleapis|api\.qr/);
});
