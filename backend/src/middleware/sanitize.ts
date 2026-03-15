import { Request, Response, NextFunction } from 'express';

/**
 * MongoDB NoSQLインジェクション対策
 * リクエストボディ・クエリ・パラメータから $ と . で始まるキーを除去
 */
function sanitizeValue(value: unknown): unknown {
  if (value === null || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(sanitizeValue);

  const sanitized: Record<string, unknown> = {};
  for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
    if (key.startsWith('$') || key.startsWith('.')) continue;
    sanitized[key] = sanitizeValue(val);
  }
  return sanitized;
}

export function sanitizeRequest(req: Request, _res: Response, next: NextFunction) {
  if (req.body) req.body = sanitizeValue(req.body);
  if (req.query) req.query = sanitizeValue(req.query) as typeof req.query;
  if (req.params) req.params = sanitizeValue(req.params) as typeof req.params;
  next();
}
