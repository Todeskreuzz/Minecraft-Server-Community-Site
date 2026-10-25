const STATUS_TTL = 120000;
const statusCache = new Map();

export function serverName(value) {
  const name = String(value ?? '').trim();
  if (name.length < 2 || name.length > 40) throw Error('Invalid name');
  return name;
}

export function serverAddress(value) {
  const address = String(value ?? '').trim().toLowerCase();
  if (!/^[a-z0-9]([a-z0-9.-]{0,78}[a-z0-9])?$/.test(address) || !address.includes('.') || address.includes('..')) throw Error('Invalid address');
  return address;
}

export function serverPort(value) {
  if (value === '' || value == null) return 25565;
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw Error('Invalid port');
  return port;
}

export function serverVersion(value) {
  const version = String(value ?? '').trim();
  if (version.length > 32) throw Error('Invalid version');
  return version;
}

export function serverDescription(value) {
  const text = String(value ?? '').trim();
  if (text.length > 240) throw Error('Invalid description');
  return text;
}

export function serverTags(value) {
  const source = Array.isArray(value) ? value.join(',') : String(value ?? '');
  const tags = [];
  for (const part of source.split(',')) {
    const tag = part.trim().toLowerCase();
    if (!tag) continue;
    if (!/^[a-z0-9-]{2,16}$/.test(tag) || tags.length >= 6) throw Error('Invalid tags');
    if (!tags.includes(tag)) tags.push(tag);
  }
  return tags;
}

export function statusUrl(address, port) {
  const host = serverAddress(address);
  const number = serverPort(port);
  return 'https://api.mcsrvstat.us/3/' + encodeURIComponent(host) + (number === 25565 ? '' : ':' + number);
}

export function readStatus(payload) {
  if (!payload || payload.online !== true) return { online: false, players: '', motd: '' };
  const online = Number(payload.players?.online);
  const max = Number(payload.players?.max);
  const players = Number.isFinite(online) && Number.isFinite(max) ? online + ' / ' + max : '';
  const motd = Array.isArray(payload.motd?.clean) ? payload.motd.clean.join(' ').replace(/\s+/g, ' ').trim().slice(0, 180) : '';
  return { online: true, players, motd };
}

export function officialServer(config) {
  const address = String(config?.server?.address || '').trim();
  if (!address) return null;
  return {
    official: true,
    name: 'Friends & Foes',
    address,
    port: 25565,
    game_version: String(config.minecraftVersion || ''),
    description: '',
    tags: [],
    is_public: true
  };
}

export function splitServers(rows, config) {
  const list = Array.isArray(rows) ? rows : [];
  return {
    official: officialServer(config),
    publicRows: list.filter(row => row.is_public !== false && !row.official),
    privateRows: list.filter(row => row.is_public === false)
  };
}

export function clearStatusCache() { statusCache.clear(); }

export async function cachedStatus(address, port, fetcher, now = Date.now()) {
  const key = serverAddress(address) + ':' + serverPort(port);
  const hit = statusCache.get(key);
  if (hit && now - hit.at < STATUS_TTL) return hit.value;
  let payload = null;
  try {
    const response = await fetcher(statusUrl(address, port));
    if (response?.ok) payload = await response.json();
  } catch { payload = null; }
  const value = readStatus(payload);
  statusCache.set(key, { at: now, value });
  return value;
}
