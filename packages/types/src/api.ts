export interface ApiError {
  error: string;
  message: string;
}

export interface ApiSuccessResponse<T> {
  data: T;
}

export interface PaginationMeta {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: PaginationMeta;
}
