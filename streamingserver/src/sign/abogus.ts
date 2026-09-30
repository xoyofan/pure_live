/**
 * a_bogus request signer for douyin web APIs.
 *
 * Faithful port of lib/core/utils/douyin/abogus.dart (which itself mirrors the
 * plain-JS signing snippet embedded in the Flutter client). All byte/string
 * manipulation uses UTF-16 code units over Latin-1-range values (0-255), like
 * Dart's String.fromCharCodes / codeUnitAt.
 */
import { sm3Bytes } from './sm3.js';

const encoder = new TextEncoder();

/** Dart String.fromCharCodes over byte values (0-255). */
function fromCharCodes(codes: number[] | Uint8Array): string {
  let out = '';
  for (const code of codes) out += String.fromCharCode(code);
  return out;
}

/** Dart String.codeUnitAt over ASCII-range strings. */
function toOrdArray(s: string): number[] {
  const out = new Array<number>(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}

/** Dart jsShiftRight: (val & 0xFFFFFFFF) >>> n with a real 64-bit shift. */
function jsShiftRight(val: number, n: number): number {
  const low = val % 0x100000000;
  if (n >= 32) return 0;
  return (low >>> n) >>> 0;
}

function generateRandomBytes(length = 3): string {
  let out = '';
  for (let i = 0; i < length; i++) {
    const rd = Math.floor(Math.random() * 10000);
    const seq = [
      ((rd & 255) & 170) | 1,
      ((rd & 255) & 85) | 2,
      (((rd >>> 8) & 255) & 170) | 5,
      (((rd >>> 8) & 255) & 85) | 40,
    ];
    out += fromCharCodes(seq);
  }
  return out;
}

function sm3ToArray(input: string | number[]): number[] {
  const bytes = typeof input === 'string' ? encoder.encode(input) : Uint8Array.from(input);
  return Array.from(sm3Bytes(bytes));
}

const BIG_ARRAY: number[] = [
  121, 243, 55, 234, 103, 36, 47, 228, 30, 231, 106, 6, 115, 95, 78, 101, 250, 207, 198, 50, 139,
  227, 220, 105, 97, 143, 34, 28, 194, 215, 18, 100, 159, 160, 43, 8, 169, 217, 180, 120, 247, 45,
  90, 11, 27, 197, 46, 3, 84, 72, 5, 68, 62, 56, 221, 75, 144, 79, 73, 161, 178, 81, 64, 187, 134,
  117, 186, 118, 16, 241, 130, 71, 89, 147, 122, 129, 65, 40, 88, 150, 110, 219, 199, 255, 181,
  254, 48, 4, 195, 248, 208, 32, 116, 167, 69, 201, 17, 124, 125, 104, 96, 83, 80, 127, 236, 108,
  154, 126, 204, 15, 20, 135, 112, 158, 13, 1, 188, 164, 210, 237, 222, 98, 212, 77, 253, 42, 170,
  202, 26, 22, 29, 182, 251, 10, 173, 152, 58, 138, 54, 141, 185, 33, 157, 31, 252, 132, 233, 235,
  102, 196, 191, 223, 240, 148, 39, 123, 92, 82, 128, 109, 57, 24, 38, 113, 209, 245, 2, 119, 153,
  229, 189, 214, 230, 174, 232, 63, 52, 205, 86, 140, 66, 175, 111, 171, 246, 133, 238, 193, 99,
  60, 74, 91, 225, 51, 76, 37, 145, 211, 166, 151, 213, 206, 0, 200, 244, 176, 218, 44, 184, 172,
  49, 216, 93, 168, 53, 21, 183, 41, 67, 85, 224, 155, 226, 242, 87, 177, 146, 70, 190, 12, 162,
  19, 137, 114, 25, 165, 163, 192, 23, 59, 9, 94, 179, 107, 35, 7, 142, 131, 239, 203, 149, 136,
  61, 249, 14, 156,
];

/** Mutating byte-substitution step; operates on a fresh copy per call. */
function transformBytes(bytesList: number[], bigArray: number[]): string {
  const bytesStr = fromCharCodes(bytesList);
  const result: string[] = [];
  let indexB = bigArray[1] as number;
  let initialValue = 0;
  let valueE = 0;

  for (let index = 0; index < bytesStr.length; index++) {
    const char = bytesStr[index] as string;
    let sumInitial = 0;

    if (index === 0) {
      initialValue = bigArray[indexB] as number;
      sumInitial = indexB + initialValue;
      bigArray[1] = initialValue;
      bigArray[indexB] = indexB;
    } else {
      sumInitial = initialValue + valueE;
    }

    const charValue = char.charCodeAt(0);
    sumInitial %= bigArray.length;
    const valueF = bigArray[sumInitial] as number;
    result.push(fromCharCodes([charValue ^ valueF]));

    valueE = bigArray[(index + 2) % bigArray.length] as number;
    sumInitial = (indexB + valueE) % bigArray.length;
    initialValue = bigArray[sumInitial] as number;
    bigArray[sumInitial] = bigArray[(index + 2) % bigArray.length] as number;
    bigArray[(index + 2) % bigArray.length] = initialValue;
    indexB = sumInitial;
  }

  return result.join('');
}

function base64Encode(inputString: string, alphabets: string[], selectedAlphabet = 0): string {
  let binaryString = '';
  for (let i = 0; i < inputString.length; i++) {
    binaryString += inputString.charCodeAt(i).toString(2).padStart(8, '0');
  }

  const paddingLength = (6 - (binaryString.length % 6)) % 6;
  binaryString += '0'.repeat(paddingLength);

  let outputString = '';
  const alphabet = alphabets[selectedAlphabet] as string;
  for (let i = 0; i < binaryString.length; i += 6) {
    outputString += alphabet[parseInt(binaryString.slice(i, i + 6), 2)];
  }
  return outputString + '='.repeat(Math.floor(paddingLength / 2));
}

function abogusEncode(abogusBytesStr: string, alphabet: string): string {
  const abogus: string[] = [];

  for (let i = 0; i < abogusBytesStr.length; i += 3) {
    let n: number;
    if (i + 2 < abogusBytesStr.length) {
      n = (abogusBytesStr.charCodeAt(i) << 16) | (abogusBytesStr.charCodeAt(i + 1) << 8) | abogusBytesStr.charCodeAt(i + 2);
    } else if (i + 1 < abogusBytesStr.length) {
      n = (abogusBytesStr.charCodeAt(i) << 16) | (abogusBytesStr.charCodeAt(i + 1) << 8);
    } else {
      n = abogusBytesStr.charCodeAt(i) << 16;
    }

    const shifts = [18, 12, 6, 0];
    const masks = [0xfc0000, 0x03f000, 0x0fc0, 0x3f];
    for (let j = 0; j < shifts.length; j++) {
      if (shifts[j] === 6 && i + 1 >= abogusBytesStr.length) break;
      if (shifts[j] === 0 && i + 2 >= abogusBytesStr.length) break;
      abogus.push((alphabet as string)[(n & (masks[j] as number)) >>> (shifts[j] as number)] as string);
    }
  }

  abogus.push('='.repeat((4 - (abogus.length % 4)) % 4));
  return abogus.join('');
}

function rc4Encrypt(key: number[], plaintext: string): number[] {
  const s = Uint8Array.from({ length: 256 }, (_, i) => i);
  let j = 0;
  for (let i = 0; i < 256; i++) {
    j = (j + (s[i] as number) + (key[i % key.length] as number)) % 256;
    const tmp = s[i] as number;
    s[i] = s[j] as number;
    s[j] = tmp;
  }
  let i = 0;
  j = 0;
  const ciphertext: number[] = [];
  for (let idx = 0; idx < plaintext.length; idx++) {
    const char = plaintext.charCodeAt(idx);
    i = (i + 1) % 256;
    j = (j + (s[i] as number)) % 256;
    const tmp = s[i] as number;
    s[i] = s[j] as number;
    s[j] = tmp;
    ciphertext.push(char ^ (s[((s[i] as number) + (s[j] as number)) % 256] as number));
  }
  return ciphertext;
}

function generateFingerprint(): string {
  const rand = (min: number, max: number) => min + Math.floor(Math.random() * (max - min + 1));
  const innerWidth = rand(1024, 1920);
  const innerHeight = rand(768, 1080);
  const outerWidth = innerWidth + rand(24, 32);
  const outerHeight = innerHeight + rand(75, 90);
  const screenY = Math.random() < 0.5 ? 0 : 30;
  const sizeWidth = rand(1024, 1920);
  const sizeHeight = rand(768, 1080);
  const availWidth = rand(1280, 1920);
  const availHeight = rand(800, 1080);
  return `${innerWidth}|${innerHeight}|${outerWidth}|${outerHeight}|0|${screenY}|0|0|${sizeWidth}|${sizeHeight}|${availWidth}|${availHeight}|${innerWidth}|${innerHeight}|24|24|Win32`;
}

const SORT_INDEX = [
  18, 20, 52, 26, 30, 34, 58, 38, 40, 53, 42, 21, 27, 54, 55, 31, 35, 57, 39, 41, 43, 22, 28, 32,
  60, 36, 23, 29, 33, 37, 44, 45, 59, 46, 47, 48, 49, 50, 24, 25, 65, 66, 70, 71,
];
const SORT_INDEX_2 = [
  18, 20, 26, 30, 34, 38, 40, 42, 21, 27, 31, 35, 39, 41, 43, 22, 28, 32, 36, 23, 29, 33, 37, 44,
  45, 46, 47, 48, 49, 50, 24, 25, 52, 53, 54, 55, 57, 58, 59, 60, 65, 66, 70, 71,
];

const CHARACTER = 'Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe';
const CHARACTER_2 = 'ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe';
const ALPHABETS = [CHARACTER, CHARACTER_2];
const SALT = 'cus';
const UA_KEY = [0, 1, 14];

export interface ABogusOptions {
  userAgent: string;
  fp?: string;
}

/**
 * Signs a query string: returns the original params suffixed with
 * `&a_bogus=<signature>` (matches ABogus.generateAbogus(params).first).
 */
export function generateAbogus(params: string, options: ABogusOptions): string {
  const userAgent = options.userAgent;
  const browserFp = options.fp && options.fp.length > 0 ? options.fp : generateFingerprint();
  const options0 = 0;
  const options1 = 1;
  const options2 = 14;
  const aid = 6383;
  const pageId = 0;

  const startEncryption = Date.now();

  const array1 = sm3ToArray(sm3ToArray(params + SALT));
  const array2 = sm3ToArray(sm3ToArray(''));
  const array3 = sm3ToArray(base64Encode(fromCharCodes(rc4Encrypt(UA_KEY, userAgent)), ALPHABETS, 1));

  const abDir = new Map<number, number>();
  const set = (k: number, v: number) => abDir.set(k, v & 0xff);

  set(8, 3);
  set(18, 44);
  set(19, 1);
  set(66, 0);
  set(69, 0);
  set(70, 0);
  set(71, 0);

  set(20, startEncryption >> 24);
  set(21, startEncryption >> 16);
  set(22, startEncryption >> 8);
  set(23, startEncryption);
  abDir.set(24, jsShiftRight(startEncryption, 32));
  abDir.set(25, jsShiftRight(startEncryption, 40));

  set(26, options0 >> 24);
  set(27, options0 >> 16);
  set(28, options0 >> 8);
  set(29, options0);

  abDir.set(30, (Math.floor(options1 / 256) & 255));
  abDir.set(31, (options1 % 256) & 255);
  abDir.set(32, ((options1 >> 24) & 255));
  abDir.set(33, ((options1 >> 16) & 255));

  set(34, options2 >> 24);
  set(35, options2 >> 16);
  set(36, options2 >> 8);
  set(37, options2);

  abDir.set(38, array1[21] as number);
  abDir.set(39, array1[22] as number);
  abDir.set(40, array2[21] as number);
  abDir.set(41, array2[22] as number);
  abDir.set(42, array3[23] as number);
  abDir.set(43, array3[24] as number);

  set(44, startEncryption >> 24);
  set(45, startEncryption >> 16);
  set(46, startEncryption >> 8);
  set(47, startEncryption);
  set(48, 3);
  abDir.set(49, jsShiftRight(startEncryption, 32));
  abDir.set(50, jsShiftRight(startEncryption, 40));

  set(51, pageId >> 24);
  set(52, pageId >> 16);
  set(53, pageId >> 8);
  set(54, pageId);
  abDir.set(55, pageId);
  abDir.set(56, aid);
  set(57, aid);
  set(58, aid >> 8);
  set(59, aid >> 16);
  set(60, aid >> 24);

  abDir.set(64, browserFp.length);
  abDir.set(65, browserFp.length);

  const sortedValues = SORT_INDEX.map((i) => abDir.get(i) ?? 0);
  const edgeFpArray = toOrdArray(browserFp);

  let abXor = 0;
  for (let index = 0; index < SORT_INDEX_2.length; index++) {
    const value = abDir.get(SORT_INDEX_2[index] as number) ?? 0;
    abXor = index === 0 ? value : abXor ^ value;
  }
  sortedValues.push(...edgeFpArray);
  sortedValues.push(abXor);

  const bigArray = BIG_ARRAY.slice();
  const abogusBytesStr = generateRandomBytes() + transformBytes(sortedValues, bigArray);
  const abogus = abogusEncode(abogusBytesStr, ALPHABETS[0] as string);
  return `${params}&a_bogus=${abogus}`;
}
