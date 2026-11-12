import { createHash, generateKeyPairSync, sign } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { authorityKeyId, checkDeviceLicense, LICENSE_PRODUCT, machineCode, type LicenseAuthority } from './device-license';
const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 3072 });
const jwk = publicKey.export({format: 'jwk'});
const authority: LicenseAuthority = {schema: 1, product: LICENSE_PRODUCT, algorithm: 'RS256', keyId: '',
  publicKey: {kty: 'RSA', n: jwk.n!, e: jwk.e!}};
authority.keyId = authorityKeyId(authority);
const now = 1800000000;
const machine = machineCode('fixture-machine-guid');
function issue(overrides: Record<string, unknown> = {}) {
  const payload = Buffer.from(JSON.stringify({v: 1, product: LICENSE_PRODUCT, kid: authority.keyId, machine,
    iat: now, exp: now+30*86400, note: 'Friend', nonce: 'a'.repeat(32), ...overrides})).toString('base64url');
  const message = `DDVS1.${payload}`;
  return `${message}.${sign('RSA-SHA256', Buffer.from(message), privateKey).toString('base64url')}`;
}
describe('owner-signed machine licenses', () => {
  it('accepts a timed license only on its machine before expiry', () => {
    expect(checkDeviceLicense(issue(),machine,authority,now+10).valid).toBe(true);
    expect(checkDeviceLicense(issue(),machineCode('another-machine'),authority,now+10)).toEqual({valid:false,reason:'wrong_machine'});
    expect(checkDeviceLicense(issue(),machine,authority,now+30*86400)).toEqual({valid:false,reason:'expired'});
  });
  it('keeps the machine code stable without sending the raw identity', () => {
    expect(machineCode('  FIXTURE-machine-guid ')).toBe(machine);
    expect(machine).toMatch(/^[A-F0-9]{4}(?:-[A-F0-9]{4}){3}$/);
    expect(machine).not.toContain('fixture');
  });
  it('accepts an explicitly perpetual owner license', () => {
    expect(checkDeviceLicense(issue({exp:null}),machine,authority,now+36500*86400).valid).toBe(true);
  });
  it('refuses payload or signature changes', () => {
    const parts=issue().split('.');
    const changed=Buffer.from(JSON.stringify({machine,exp:null})).toString('base64url');
    expect(checkDeviceLicense(`DDVS1.${changed}.${parts[2]}`,machine,authority,now).valid).toBe(false);
    const signature=Buffer.from(parts[2],'base64url');signature[0]^=1;
    expect(checkDeviceLicense(`DDVS1.${parts[1]}.${signature.toString('base64url')}`,machine,authority,now).valid).toBe(false);
  });
  it('rejects another issuing key and product', () => {
    expect(checkDeviceLicense(issue({product:'another-product'}),machine,authority,now).valid).toBe(false);
    const other=generateKeyPairSync('rsa',{modulusLength:2048}).publicKey.export({format:'jwk'});
    const wrong={...authority,publicKey:{kty:'RSA' as const,n:other.n!,e:other.e!}};
    wrong.keyId=authorityKeyId(wrong);
    expect(checkDeviceLicense(issue(),machine,wrong,now).valid).toBe(false);
  });
  it('detects time before issuance and ordinary clock rollback', () => {
    expect(checkDeviceLicense(issue(),machine,authority,now-301)).toEqual({valid:false,reason:'clock'});
    expect(checkDeviceLicense(issue(),machine,authority,now+50,now+1000)).toEqual({valid:false,reason:'clock'});
  });
  it.each([{iat:'1800000000'},{exp:'forever'},{exp:now-1},{machine:'abc'},{note:7},{v:2},{nonce:'bad'}])('rejects malformed signed claims %j', (changes) => {
    expect(checkDeviceLicense(issue(changes),machine,authority,now).valid).toBe(false);
  });
  it('rejects missing, oversized and unsupported tokens', () => {
    for(const token of ['', 'DDVS2.a.b', 'x'.repeat(8193)]) expect(checkDeviceLicense(token,machine,authority,now).valid).toBe(false);
  });
  it('matches the documented public key id construction', () => {
    expect(authority.keyId).toBe(createHash('sha256').update(`${jwk.n}.${jwk.e}`).digest('hex').slice(0,16));
  });
});
