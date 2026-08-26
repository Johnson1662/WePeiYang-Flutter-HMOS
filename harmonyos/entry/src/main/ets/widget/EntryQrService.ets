import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import fs from '@ohos.file.fs';

const TAG: string = 'EntryQrService';
const BASE_URL: string = 'https://f.tju.edu.cn/tp_up/up/mobile/ifs/';
const USER_NUMBER_FILE: string = 'schedule_widget_data.json';
const SID_KEY: string = 'userNumber';
const DES_KEY: string = 'neusofteducationplatform';
const DES_IV: string = '01234567';

export interface EntryQrData {
  qrContent: string;
  status: string;
  lastUpdate: string;
}

function bytesFromText(value: string): Uint8Array {
  return new Uint8Array(buffer.from(value, 'utf-8').buffer);
}

function bytesToHex(data: Uint8Array): string {
  let result: string = '';
  for (let i = 0; i < data.length; i++) {
    result += data[i].toString(16).padStart(2, '0').toUpperCase();
  }
  return result;
}

async function encryptPath(source: string): Promise<string> {
  if (!canIUse('SystemCapability.Security.CryptoFramework')) {
    throw new Error('当前设备不支持二维码加密');
  }
  const keyGenerator = cryptoFramework.createSymKeyGenerator('3DES192');
  const key = await keyGenerator.convertKey({ data: bytesFromText(DES_KEY) });
  const iv: cryptoFramework.IvParamsSpec = {
    algName: 'IvParamsSpec',
    iv: { data: bytesFromText(DES_IV) }
  };
  const cipher = cryptoFramework.createCipher('3DES192|CBC|PKCS7');
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, iv);
  const encrypted = await cipher.doFinal({ data: bytesFromText(source) });
  return bytesToHex(encrypted.data);
}

function readSid(cacheDirs: string[]): string {
  for (const cacheDir of cacheDirs) {
    try {
      const path: string = cacheDir + '/' + USER_NUMBER_FILE;
      const data: Record<string, Object> = JSON.parse(fs.readTextSync(path));
      const sid: string = (data[SID_KEY] as string) || '';
      if (sid.trim().length > 0) return sid.trim();
    } catch (e) {
      console.warn(TAG, 'read sid failed: ' + JSON.stringify(e));
    }
  }
  return '';
}

function findMessage(data: Record<string, Object>): string {
  const message: Object = data['message'];
  if (typeof message === 'string' && message.length > 0) {
    return message;
  }

  for (const key of ['data', 'result', 'response']) {
    const nested: Object = data[key];
    if (nested !== null && typeof nested === 'object' && !Array.isArray(nested)) {
      const found: string = findMessage(nested as Record<string, Object>);
      if (found.length > 0) return found;
    }
  }
  return '';
}

function decodeXml(value: string): string {
  return value
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function extractQrContent(body: string): string {
  const trimmed: string = body.trim();
  if (trimmed.startsWith('{')) {
    try {
      return findMessage(JSON.parse(trimmed) as Record<string, Object>);
    } catch (e) {
      console.warn(TAG, 'parse JSON failed: ' + JSON.stringify(e));
      return '';
    }
  }

  const match: RegExpMatchArray | null = trimmed.match(/<message[^>]*>([\s\S]*?)<\/message>/i);
  return match !== null && match.length > 1 ? decodeXml(match[1]) : '';
}

async function fetchQrContent(sid: string): Promise<string> {
  if (sid.length === 0) return '';

  const encryptedPath: string = await encryptPath(
    'method=getAccountQRcodeInfo&ID_NUMBER=' + sid
  );
  const request = http.createHttp();
  try {
    const response = await request.request(BASE_URL + encryptedPath, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 8000,
      readTimeout: 8000,
      header: {
        'Content-Type': 'application/json;charset=UTF-8',
        'Accept': 'application/json;charset=UTF-8',
        'Host': 'f.tju.edu.cn',
        'Connection': 'Keep-Alive',
        'Accept-Encoding': 'gzip',
        'User-Agent': 'okhttp/3.12.0'
      }
    });
    if (Number(response.responseCode) < 200 || Number(response.responseCode) >= 300) {
      console.warn(TAG, 'request failed: ' + response.responseCode);
      return '';
    }
    const body: string = typeof response.result === 'string'
      ? response.result
      : JSON.stringify(response.result);
    return extractQrContent(body);
  } finally {
    request.destroy();
  }
}

export async function loadEntryQrData(cacheDirs: string[]): Promise<EntryQrData> {
  const sid: string = readSid(cacheDirs);
  if (sid.length === 0) {
    return {
      qrContent: '',
      status: '请先登录微北洋',
      lastUpdate: ''
    };
  }

  try {
    const content: string = await fetchQrContent(sid);
    if (content.length === 0) {
      return {
        qrContent: '',
        status: '二维码获取失败，请点击刷新',
        lastUpdate: ''
      };
    }
    return {
      qrContent: content,
      status: '二维码有效期约 3 分钟',
      lastUpdate: '更新于 ' + new Date().toLocaleTimeString()
    };
  } catch (e) {
    console.error(TAG, 'load QR failed: ' + JSON.stringify(e));
    return {
      qrContent: '',
      status: '二维码获取失败，请点击刷新',
      lastUpdate: ''
    };
  }
}
