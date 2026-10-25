const BECH32 = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
const BASE58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const MASK64 = (1n << 64n) - 1n;
const KECCAK_RC = [
  0x0000000000000001n, 0x0000000000008082n, 0x800000000000808an, 0x8000000080008000n,
  0x000000000000808bn, 0x0000000080000001n, 0x8000000080008081n, 0x8000000000008009n,
  0x000000000000008an, 0x0000000000000088n, 0x0000000080008009n, 0x000000008000000an,
  0x000000008000808bn, 0x800000000000008bn, 0x8000000000008089n, 0x8000000000008003n,
  0x8000000000008002n, 0x8000000000000080n, 0x000000000000800an, 0x800000008000000an,
  0x8000000080008081n, 0x8000000000008080n, 0x0000000080000001n, 0x8000000080008008n
];
const KECCAK_ROT = [
  [0, 36, 3, 41, 18],
  [1, 44, 10, 45, 2],
  [62, 6, 43, 15, 61],
  [28, 55, 25, 21, 56],
  [27, 20, 39, 8, 14]
];

function rotl(value, bits) {
  if (!bits) return value;
  return ((value << BigInt(bits)) | (value >> BigInt(64 - bits))) & MASK64;
}

function keccakF(state) {
  for (let round = 0; round < 24; round++) {
    const c = [0n, 0n, 0n, 0n, 0n];
    for (let x = 0; x < 5; x++) c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
    const d = c.map((_, x) => c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1));
    for (let i = 0; i < 25; i++) state[i] ^= d[i % 5];
    const next = new Array(25);
    for (let x = 0; x < 5; x++) for (let y = 0; y < 5; y++) next[y + 5 * ((2 * x + 3 * y) % 5)] = rotl(state[x + 5 * y], KECCAK_ROT[x][y]);
    for (let y = 0; y < 5; y++) for (let x = 0; x < 5; x++) {
      state[x + 5 * y] = (next[x + 5 * y] ^ ((~next[((x + 1) % 5) + 5 * y]) & next[((x + 2) % 5) + 5 * y])) & MASK64;
    }
    state[0] = (state[0] ^ KECCAK_RC[round]) & MASK64;
  }
}

export function keccak256(bytes) {
  const rate = 136;
  const state = new Array(25).fill(0n);
  const input = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const absorb = block => {
    for (let i = 0; i < rate; i += 8) {
      let lane = 0n;
      for (let b = 0; b < 8; b++) lane |= BigInt(block[i + b]) << BigInt(8 * b);
      state[i / 8] ^= lane;
    }
    keccakF(state);
  };
  let offset = 0;
  while (offset + rate <= input.length) {
    absorb(input.subarray(offset, offset + rate));
    offset += rate;
  }
  const padded = new Uint8Array(rate);
  padded.set(input.subarray(offset));
  padded[input.length - offset] ^= 0x01;
  padded[rate - 1] ^= 0x80;
  absorb(padded);
  const out = new Uint8Array(32);
  for (let i = 0; i < out.length; i++) out[i] = Number((state[Math.floor(i / 8)] >> BigInt(8 * (i % 8))) & 255n);
  return out;
}

function bech32Polymod(values) {
  const gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
  let chk = 1;
  for (const value of values) {
    const top = chk >>> 25;
    chk = ((chk & 0x1ffffff) << 5) ^ value;
    for (let i = 0; i < 5; i++) if ((top >>> i) & 1) chk ^= gen[i];
    chk >>>= 0;
  }
  return chk;
}

function convertBits(values, from, to) {
  let acc = 0;
  let bits = 0;
  const out = [];
  const max = (1 << to) - 1;
  for (const value of values) {
    acc = (acc << from) | value;
    bits += from;
    while (bits >= to) {
      bits -= to;
      out.push((acc >> bits) & max);
    }
  }
  if (bits >= from || (acc << (to - bits) & max)) return null;
  return out;
}

export function bitcoinOk(address) {
  if (typeof address !== 'string' || address !== address.toLowerCase()) return false;
  const split = address.lastIndexOf('1');
  if (split < 1 || address.slice(0, split) !== 'bc') return false;
  const data = address.slice(split + 1);
  if (data.length < 6) return false;
  const values = [];
  for (const char of data) {
    const value = BECH32.indexOf(char);
    if (value < 0) return false;
    values.push(value);
  }
  if (bech32Polymod([3, 3, 0, 2, 3].concat(values)) !== 1 || values[0] !== 0) return false;
  const program = convertBits(values.slice(1, -6), 5, 8);
  return !!program && (program.length === 20 || program.length === 32);
}

export function ethereumChecksum(address) {
  const body = String(address).replace(/^0x/i, '').toLowerCase();
  const hash = keccak256(new TextEncoder().encode(body));
  let mixed = '0x';
  for (let i = 0; i < body.length; i++) {
    const nibble = (hash[i >> 1] >> ((i & 1) ? 0 : 4)) & 0xf;
    const char = body[i];
    mixed += nibble >= 8 ? char.toUpperCase() : char;
  }
  return mixed;
}

export function ethereumOk(address) {
  return typeof address === 'string' && /^0x[0-9a-fA-F]{40}$/.test(address) && ethereumChecksum(address) === address;
}

export function base58Bytes(address) {
  if (typeof address !== 'string' || !address) return null;
  let value = 0n;
  for (const char of address) {
    const index = BASE58.indexOf(char);
    if (index < 0) return null;
    value = value * 58n + BigInt(index);
  }
  const bytes = [];
  while (value > 0n) {
    bytes.push(Number(value & 255n));
    value >>= 8n;
  }
  bytes.reverse();
  let zeros = 0;
  for (const char of address) {
    if (char !== '1') break;
    zeros++;
  }
  return new Array(zeros).fill(0).concat(bytes.length ? bytes : []);
}

export function solanaOk(address) {
  const bytes = base58Bytes(address);
  return !!bytes && bytes.length === 32;
}

const COINS = [
  { id: 'bitcoin', symbol: 'BTC', network: 'Bitcoin', check: bitcoinOk },
  { id: 'ethereum', symbol: 'ETH', network: 'Ethereum', check: ethereumOk },
  { id: 'solana', symbol: 'SOL', network: 'Solana', check: solanaOk }
];

export function supportEntries(config) {
  const crypto = config?.support?.crypto;
  if (!crypto || typeof crypto !== 'object') return [];
  return COINS.map(coin => ({ ...coin, address: String(crypto[coin.id] || '').trim() })).filter(coin => coin.address);
}
