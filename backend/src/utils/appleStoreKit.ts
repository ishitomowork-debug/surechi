/**
 * Apple StoreKit 2 サーバーサイド JWS トランザクション検証
 *
 * StoreKit 2 では、クライアントから送られる signedTransaction は
 * Apple が署名した JWS (JSON Web Signature) 形式のトークンです。
 * JWS の x5c ヘッダーに含まれる証明書チェーンを Apple Root CA で検証し、
 * ペイロードのトランザクション情報を取得します。
 *
 * --- Apple Root CA 証明書の取得方法 ---
 * 1. https://www.apple.com/certificateauthority/ から
 *    「Apple Root CA - G3」をダウンロード (DER 形式)
 * 2. PEM に変換:
 *    openssl x509 -inform der -in AppleRootCA-G3.cer -out AppleRootCA-G3.pem
 * 3. 環境変数 APPLE_ROOT_CA_PEM にその PEM 文字列をセットするか、
 *    このファイル内の APPLE_ROOT_CA_G3_PEM 定数を差し替えてください。
 *
 * --- Sandbox 環境 ---
 * Sandbox テスト時は環境変数 APP_STORE_ENVIRONMENT=sandbox を設定すると
 * ペイロードの environment チェックが "Sandbox" を許可します。
 */

import * as jose from 'jose';
import { X509Certificate } from 'crypto';

// Apple Root CA - G3 の公開鍵 (PEM)
// 本番運用時は環境変数 APPLE_ROOT_CA_PEM から読み込むことを推奨
const APPLE_ROOT_CA_G3_PEM = `-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS
QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN
MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS
b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49
AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf
TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK515
1Du8SxO5LZR2zKNjMGEwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8G
A1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUu7DeoVgziJqkipnevr3rr9rLJKsw
DgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v
9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82N
QI6F5S1J56+UG6OBqYAkiJwvrILuoJc6nJ4AIuiqvCMJb27/Mg==
-----END CERTIFICATE-----`;

/**
 * StoreKit 2 JWS トランザクションペイロードの型定義
 * Apple ドキュメント: https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload
 */
export interface StoreKit2TransactionPayload {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;
  originalPurchaseDate: number;
  quantity: number;
  type: string;
  environment: 'Production' | 'Sandbox' | 'Xcode';
  storefront: string;
  storefrontId: string;
  signedDate: number;
  // 消耗型の場合は以下は含まれない場合がある
  expiresDate?: number;
  inAppOwnershipType?: string;
  revocationDate?: number;
  revocationReason?: number;
}

/**
 * Apple の JWS (signedTransaction) を検証し、デコードされたペイロードを返す
 *
 * 検証手順:
 * 1. JWS ヘッダーから x5c (証明書チェーン) を取得
 * 2. 証明書チェーンを Apple Root CA - G3 で検証
 * 3. リーフ証明書の公開鍵で JWS 署名を検証
 * 4. ペイロードをデコードして返す
 */
export async function verifyAppleJWS(
  signedTransaction: string
): Promise<StoreKit2TransactionPayload> {
  // JWS ヘッダーをデコードして x5c を取得
  const protectedHeader = jose.decodeProtectedHeader(signedTransaction);

  if (!protectedHeader.x5c || protectedHeader.x5c.length === 0) {
    throw new AppleVerificationError('JWS header missing x5c certificate chain');
  }

  // x5c は Base64 エンコードされた DER 証明書の配列
  // [0] = リーフ証明書 (署名に使用), [1] = 中間証明書, ...
  const certChain = protectedHeader.x5c;

  // 証明書チェーンを検証
  verifyCertificateChain(certChain);

  // リーフ証明書から公開鍵を取得して JWS を検証
  const leafCertPem = derToPem(certChain[0]);
  const publicKey = await jose.importX509(leafCertPem, protectedHeader.alg as string);

  const { payload } = await jose.jwtVerify(signedTransaction, publicKey, {
    // Apple の JWS は JWT 形式だが iss/aud は検証不要
    // clockTolerance で多少の時刻ずれを許容
    clockTolerance: 60,
  }).catch(() => {
    throw new AppleVerificationError('JWS signature verification failed');
  });

  const txPayload = payload as unknown as StoreKit2TransactionPayload;

  // bundleId の検証 (環境変数で設定)
  const expectedBundleId = process.env.APPLE_BUNDLE_ID;
  if (expectedBundleId && txPayload.bundleId !== expectedBundleId) {
    throw new AppleVerificationError(
      `Bundle ID mismatch: expected ${expectedBundleId}, got ${txPayload.bundleId}`
    );
  }

  // environment の検証
  const allowSandbox = process.env.APP_STORE_ENVIRONMENT === 'sandbox';
  if (txPayload.environment === 'Sandbox' && !allowSandbox) {
    throw new AppleVerificationError(
      'Sandbox transaction received in production mode'
    );
  }

  return txPayload;
}

/**
 * x5c 証明書チェーンを Apple Root CA で検証する
 *
 * Node.js の crypto.X509Certificate を使用してチェーンを辿り、
 * 最終的に Apple Root CA - G3 に到達することを確認する。
 */
function verifyCertificateChain(x5cChain: string[]): void {
  const rootCaPem = process.env.APPLE_ROOT_CA_PEM || APPLE_ROOT_CA_G3_PEM;
  const rootCert = new X509Certificate(rootCaPem);

  // 証明書チェーンを PEM 形式に変換
  const certs = x5cChain.map((der) => new X509Certificate(derToPem(der)));

  // チェーンを下から上へ検証:
  // certs[0] は certs[1] に署名されている
  // certs[1] は certs[2] に署名されている (あれば)
  // 最後の証明書は Root CA に署名されている
  for (let i = 0; i < certs.length; i++) {
    const issuer = i + 1 < certs.length ? certs[i + 1] : rootCert;
    if (!certs[i].checkIssued(issuer)) {
      throw new AppleVerificationError(
        `Certificate chain verification failed at index ${i}`
      );
    }
  }

  // 最上位の証明書が Apple Root CA で署名されていることを確認
  const topCert = certs[certs.length - 1];
  if (!topCert.checkIssued(rootCert)) {
    throw new AppleVerificationError(
      'Certificate chain does not terminate at Apple Root CA'
    );
  }
}

/**
 * Base64 エンコードされた DER 証明書を PEM 形式に変換
 */
function derToPem(base64Der: string): string {
  const lines: string[] = [];
  lines.push('-----BEGIN CERTIFICATE-----');
  // 64文字ごとに改行
  for (let i = 0; i < base64Der.length; i += 64) {
    lines.push(base64Der.substring(i, i + 64));
  }
  lines.push('-----END CERTIFICATE-----');
  return lines.join('\n');
}

/**
 * Apple 検証固有のエラークラス
 */
export class AppleVerificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AppleVerificationError';
  }
}
