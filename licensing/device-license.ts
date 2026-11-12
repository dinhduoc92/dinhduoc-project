import { createHash, createPublicKey, verify } from 'node:crypto';

export const LICENSE_PRODUCT = 'vn.dinhduoc.voicestudio';
export interface LicenseAuthority {
  schema: 1;
  product: string;
  algorithm: 'RS256';
  keyId: string;
  publicKey: { kty: 'RSA'; n: string; e: string };
}
export interface DeviceLicense {
  v: 1;
  product: string;
  kid: string;
  machine: string;
  iat: number;
  exp: number | null;
  note: string;
  nonce: string;
}
export type LicenseFailure = 'invalid' | 'wrong_machine' | 'expired' | 'clock' | 'authority';
export type LicenseVerdict = { valid: true; claims: DeviceLicense } | { valid: false; reason: LicenseFailure };

export function machineCode(identity: string): string {
  if (!identity.trim()) throw new Error('Machine identity is unavailable');
  const hash = createHash('sha256').update(`${LICENSE_PRODUCT}\0${identity.trim().toLowerCase()}`).digest('hex');
  return hash.slice(0, 16).toUpperCase().match(/.{4}/g)!.join('-');
}

export function authorityKeyId(authority: LicenseAuthority): string {
  return createHash('sha256').update(`${authority.publicKey.n}.${authority.publicKey.e}`).digest('hex').slice(0, 16);
}

/** Verify the original signed bytes, never a reserialized JSON document. */
export function checkDeviceLicense(
  token: string,
  machine: string,
  authority: LicenseAuthority,
  nowSeconds = Math.floor(Date.now() / 1000),
  lastSeenSeconds = 0,
): LicenseVerdict {
  try {
    if (authority.schema !== 1 || authority.product !== LICENSE_PRODUCT || authority.algorithm !== 'RS256' ||
        authority.publicKey.kty !== 'RSA' || authorityKeyId(authority) !== authority.keyId)
      return { valid: false, reason: 'authority' };
    const key = createPublicKey({ key: authority.publicKey, format: 'jwk' });
    if (key.asymmetricKeyType !== 'rsa' || (key.asymmetricKeyDetails?.modulusLength ?? 0) < 2048)
      return { valid: false, reason: 'authority' };
    if (!Number.isSafeInteger(nowSeconds) || !Number.isSafeInteger(lastSeenSeconds))
      return { valid: false, reason: 'clock' };
    if (nowSeconds + 300 < lastSeenSeconds) return { valid: false, reason: 'clock' };
    const value = token.trim();
    if (value.length > 8192) return { valid: false, reason: 'invalid' };
    const parts = /^DDVS1\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$/.exec(value);
    if (!parts) return { valid: false, reason: 'invalid' };
    if (!verify('RSA-SHA256', Buffer.from(`DDVS1.${parts[1]}`, 'utf8'), key, Buffer.from(parts[2], 'base64url')))
      return { valid: false, reason: 'invalid' };
    const claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8')) as DeviceLicense;
    if (!claims || claims.v !== 1 || claims.product !== LICENSE_PRODUCT || claims.kid !== authority.keyId ||
        !/^[A-F0-9]{4}(?:-[A-F0-9]{4}){3}$/.test(claims.machine) ||
        !Number.isSafeInteger(claims.iat) || claims.iat <= 0 ||
        (claims.exp !== null && (!Number.isSafeInteger(claims.exp) || claims.exp <= claims.iat)) ||
        typeof claims.note !== 'string' || claims.note.length > 200 ||
        typeof claims.nonce !== 'string' || !/^[a-f0-9]{32}$/.test(claims.nonce))
      return { valid: false, reason: 'invalid' };
    if (claims.machine !== machine) return { valid: false, reason: 'wrong_machine' };
    if (nowSeconds + 300 < claims.iat) return { valid: false, reason: 'clock' };
    if (claims.exp !== null && nowSeconds >= claims.exp) return { valid: false, reason: 'expired' };
    return { valid: true, claims };
  } catch {
    return { valid: false, reason: 'invalid' };
  }
}
