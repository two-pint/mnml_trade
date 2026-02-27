export interface User {
  id: string;
  email: string;
  username: string | null;
  email_verified: boolean;
  avatar_url: string | null;
  created_at: string;
  updated_at: string;
}
