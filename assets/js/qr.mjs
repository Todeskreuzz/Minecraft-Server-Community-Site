const SIZE = 29;
const DATA = 55;
const ECC = 15;
const EXP = new Uint8Array(512);
const LOG = new Uint8Array(256);
{
  let x = 1;
  for (let i = 0; i < 255; i++) {
    EXP[i] = x;
    LOG[x] = i;
    x <<= 1;
    if (x & 0x100) x ^= 0x11d;
  }
  for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];
}
const GEN15 = [8, 183, 61, 91, 202, 37, 51, 58, 58, 237, 140, 124, 5, 99, 105];

function remainder(data) {
  const block = data.concat(new Array(ECC).fill(0));
  for (let k = 0; k < data.length; k++) {
    const coef = block[k];
    if (!coef) continue;
    const lcoef = LOG[coef];
    for (let n = 0; n < ECC; n++) block[k + n + 1] ^= EXP[lcoef + GEN15[n]];
  }
  return block.slice(data.length);
}

function codewords(text) {
  const bytes = [...new TextEncoder().encode(text)];
  if (bytes.length > 53) throw Error('QR text is too long');
  const bits = [];
  const push = (value, len) => { for (let i = len - 1; i >= 0; i--) bits.push((value >> i) & 1); };
  push(0b0100, 4);
  push(bytes.length, 8);
  for (const byte of bytes) push(byte, 8);
  for (let i = 0; i < 4 && bits.length < DATA * 8; i++) bits.push(0);
  while (bits.length % 8) bits.push(0);
  const pad = [0xec, 0x11];
  let p = 0;
  while (bits.length < DATA * 8) push(pad[p++ % 2], 8);
  const data = [];
  for (let i = 0; i < DATA; i++) {
    let n = 0;
    for (let b = 0; b < 8; b++) n = (n << 1) | bits[i * 8 + b];
    data.push(n);
  }
  return data.concat(remainder(data));
}

const MASKS = [
  (r, c) => (r + c) % 2 === 0,
  (r, c) => r % 2 === 0,
  (r, c) => c % 3 === 0,
  (r, c) => (r + c) % 3 === 0,
  (r, c) => (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0,
  (r, c) => (r * c) % 2 + (r * c) % 3 === 0,
  (r, c) => ((r * c) % 2 + (r * c) % 3) % 2 === 0,
  (r, c) => ((r + c) % 2 + (r * c) % 3) % 2 === 0
];

function blank() {
  const m = Array.from({ length: SIZE }, () => Array(SIZE).fill(null));
  const set = (r, c, v) => { if (r >= 0 && c >= 0 && r < SIZE && c < SIZE) m[r][c] = v; };
  const finder = (r0, c0) => {
    for (let r = 0; r < 7; r++) for (let c = 0; c < 7; c++) set(r0 + r, c0 + c, r === 0 || c === 0 || r === 6 || c === 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4) ? 1 : 0);
    for (let i = -1; i < 8; i++) { set(r0 - 1, c0 + i, 0); set(r0 + 7, c0 + i, 0); set(r0 + i, c0 - 1, 0); set(r0 + i, c0 + 7, 0); }
  };
  finder(0, 0); finder(0, SIZE - 7); finder(SIZE - 7, 0);
  for (let i = 8; i < SIZE - 8; i++) { set(6, i, i % 2 === 0 ? 1 : 0); set(i, 6, i % 2 === 0 ? 1 : 0); }
  for (let r = -2; r <= 2; r++) for (let c = -2; c <= 2; c++) set(22 + r, 22 + c, Math.max(Math.abs(r), Math.abs(c)) !== 1 ? 1 : 0);
  set(SIZE - 8, 8, 1);
  const format = [[8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5], [8, 7], [8, 8], [7, 8], [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8]];
  for (let i = 0; i < 7; i++) format.push([SIZE - 1 - i, 8]);
  for (let i = 0; i < 8; i++) format.push([8, SIZE - 8 + i]);
  for (const [r, c] of format) set(r, c, 0);
  return m;
}

function formatBits(mask) {
  const data = (0b01 << 3) | mask;
  let rem = data << 10;
  for (let i = 14; i >= 10; i--) if ((rem >> i) & 1) rem ^= 0x537 << (i - 10);
  return (((data << 10) | (rem & 0x3ff)) ^ 0x5412) & 0x7fff;
}

function applyFormat(m, mask) {
  const bits = formatBits(mask);
  const a = [[8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5], [8, 7], [8, 8], [7, 8], [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8]];
  const b = [];
  for (let i = 0; i < 7; i++) b.push([SIZE - 1 - i, 8]);
  for (let i = 0; i < 8; i++) b.push([8, SIZE - 8 + i]);
  for (let i = 0; i < 15; i++) {
    const bit = (bits >> (14 - i)) & 1;
    m[a[i][0]][a[i][1]] = bit;
    m[b[i][0]][b[i][1]] = bit;
  }
}

function penalty(m) {
  let score = 0;
  const addRun = (n) => { if (n >= 5) score += 3 + n - 5; };
  for (let r = 0; r < SIZE; r++) {
    let dark = m[r][0], n = 1;
    for (let c = 1; c < SIZE; c++) { if (m[r][c] === dark) n++; else { addRun(n); dark = m[r][c]; n = 1; } }
    addRun(n);
  }
  for (let c = 0; c < SIZE; c++) {
    let dark = m[0][c], n = 1;
    for (let r = 1; r < SIZE; r++) { if (m[r][c] === dark) n++; else { addRun(n); dark = m[r][c]; n = 1; } }
    addRun(n);
  }
  for (let r = 0; r < SIZE - 1; r++) for (let c = 0; c < SIZE - 1; c++) if (m[r][c] === m[r][c + 1] && m[r][c] === m[r + 1][c] && m[r][c] === m[r + 1][c + 1]) score += 3;
  const darks = m.flat().reduce((n, v) => n + v, 0);
  score += Math.floor(Math.abs(darks / (SIZE * SIZE) * 100 - 50) / 5) * 10;
  return score;
}

function draw(words, mask) {
  const m = blank();
  const bits = [];
  for (const word of words) for (let i = 7; i >= 0; i--) bits.push((word >> i) & 1);
  let i = 0;
  let up = true;
  for (let col = SIZE - 1; col > 0; col -= 2) {
    if (col === 6) col--;
    for (let row = 0; row < SIZE; row++) {
      const r = up ? SIZE - 1 - row : row;
      for (const c of [col, col - 1]) if (m[r][c] === null) {
        const bit = i < bits.length ? bits[i++] : 0;
        m[r][c] = bit ^ (MASKS[mask](r, c) ? 1 : 0);
      }
    }
    up = !up;
  }
  applyFormat(m, mask);
  return m;
}

export function qrMatrix(text) {
  const words = codewords(text);
  let best = null;
  let bestScore = Infinity;
  for (let mask = 0; mask < 8; mask++) {
    const m = draw(words, mask);
    const score = penalty(m);
    if (score < bestScore) { best = m; bestScore = score; }
  }
  return best;
}
