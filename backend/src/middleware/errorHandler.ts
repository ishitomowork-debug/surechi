import { Request, Response, NextFunction } from 'express';

export class AppError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number = 500) {
    super(message);
    this.statusCode = statusCode;
  }
}

export function errorHandler(
  error: AppError | Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  const statusCode = error instanceof AppError ? error.statusCode : 500;
  const message = error.message || 'Internal server error';

  console.error(`[${new Date().toISOString()}] Error:`, error);

  const isProduction = process.env.NODE_ENV === 'production';

  res.status(statusCode).json({
    error: isProduction && statusCode === 500 ? 'Internal server error' : message,
    statusCode,
    ...(isProduction ? {} : { stack: error.stack }),
  });
}

export default errorHandler;
