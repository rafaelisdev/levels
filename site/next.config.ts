import type { NextConfig } from "next";

const config: NextConfig = {
  poweredByHeader: false,
  images: { formats: ["image/avif", "image/webp"] },
  // One canonical host: www.getlevels.app -> getlevels.app (permanent).
  async redirects() {
    return [
      {
        source: "/:path*",
        has: [{ type: "host", value: "www.getlevels.app" }],
        destination: "https://getlevels.app/:path*",
        permanent: true,
      },
    ];
  },
};

export default config;
