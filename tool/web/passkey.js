// Device unlock with Face ID / Touch ID / fingerprint via a passkey stored
// on this phone. Used only as a local app lock; no server is involved.
(function () {
  function b64(buf) {
    var s = '', b = new Uint8Array(buf);
    for (var i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  function unb64(str) {
    str = str.replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) str += '=';
    var s = atob(str), b = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) b[i] = s.charCodeAt(i);
    return b.buffer;
  }
  function rnd(n) { return crypto.getRandomValues(new Uint8Array(n)); }
  window.b9Passkey = {
    available: async function () {
      try {
        return !!(window.PublicKeyCredential &&
          await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable());
      } catch (e) { return false; }
    },
    register: async function () {
      try {
        var cred = await navigator.credentials.create({ publicKey: {
          challenge: rnd(32),
          rp: { name: 'Bills O9 Time' },
          user: { id: rnd(16), name: 'Bills O9 Time', displayName: 'Bills O9 Time lock' },
          pubKeyCredParams: [{ type: 'public-key', alg: -7 }, { type: 'public-key', alg: -257 }],
          authenticatorSelection: { authenticatorAttachment: 'platform', userVerification: 'required', residentKey: 'discouraged' },
          timeout: 60000
        }});
        return cred ? b64(cred.rawId) : null;
      } catch (e) { return null; }
    },
    verify: async function (id) {
      try {
        var r = await navigator.credentials.get({ publicKey: {
          challenge: rnd(32),
          allowCredentials: [{ type: 'public-key', id: unb64(id) }],
          userVerification: 'required',
          timeout: 60000
        }});
        return !!r;
      } catch (e) { return false; }
    }
  };
})();
