import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Rack Up — Onchain Hi-Lo",
    short_name: "Rack Up",
    description: "Live Hi-Lo on Base Sepolia",
    start_url: "/",
    display: "standalone",
    background_color: "#071b15",
    theme_color: "#071b15",
  };
}

