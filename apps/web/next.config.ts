import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@repo/ui", "@repo/api-client", "@repo/types", "@repo/utils"],
};

export default nextConfig;
