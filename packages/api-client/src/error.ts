import type { ApiError } from "@repo/types";

export class ApiClientError extends Error {
  public readonly status: number;
  public readonly error: ApiError;

  constructor(status: number, error: ApiError) {
    super(error.message);
    this.name = "ApiClientError";
    this.status = status;
    this.error = error;
  }
}
