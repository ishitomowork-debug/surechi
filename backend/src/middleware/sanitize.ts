import { Request, Response, NextFunction } from 'express';

const MAX_DEPTH = 10;

/**
 * MongoDB NoSQLインジェクション対策
 * - $ と . で始まるキーを除去
 * - null bytes を除去
 * - 再帰的にネストされたオブジェクトもサニタイズ
 * - 深さ制限（10レベル）で無限再帰を防止
 */
function sanitizeValue(value: unknown, depth: number = 0): unknown {
  // 深さ制限を超えたら値を破棄
  if (depth > MAX_DEPTH) return undefined;

  // null / undefined はそのまま返す
  if (value === null || value === undefined) return value;

  // 文字列の場合、null bytes を除去
  if (typeof value === 'string') {
    return value.replace(/\0/g, '');
  }

  // プリミティブ（number, boolean）はそのまま返す
  if (typeof value !== 'object') return value;

  // 配列の場合、各要素を再帰的にサニタイズ
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeValue(item, depth + 1));
  }

  // オブジェクトの場合、キーと値を再帰的にサニタイズ
  const sanitized: Record<string, unknown> = {};
  for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
    // $ や . で始まるキーは NoSQL インジェクションの可能性があるため除去
    if (key.startsWith('$') || key.startsWith('.')) continue;
    // キー自体に null bytes が含まれていたらスキップ
    if (key.includes('\0')) continue;
    sanitized[key] = sanitizeValue(val, depth + 1);
  }
  return sanitized;
}

export function sanitizeRequest(req: Request, _res: Response, next: NextFunction) {
  if (req.body) req.body = sanitizeValue(req.body);
  if (req.query) req.query = sanitizeValue(req.query) as typeof req.query;
  if (req.params) req.params = sanitizeValue(req.params) as typeof req.params;
  next();
}
