/** Throw from handlers; the app error handler turns it into {error, message} with this status. */
export class HttpError extends Error {
  statusCode: number;
  code: string;
  constructor(statusCode: number, code: string, message: string) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }
}
