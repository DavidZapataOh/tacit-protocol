import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // shadcn/ui CSS variable colors
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        chart: {
          "1": "hsl(var(--chart-1))",
          "2": "hsl(var(--chart-2))",
          "3": "hsl(var(--chart-3))",
          "4": "hsl(var(--chart-4))",
          "5": "hsl(var(--chart-5))",
        },
        // Brand accent — Emerald
        brand: {
          50: "#ecfdf5",
          100: "#d1fae5",
          200: "#a7f3d0",
          300: "#6ee7b7",
          400: "#34d399",
          500: "#10b981",
          600: "#059669",
          700: "#047857",
          800: "#065f46",
          900: "#064e3b",
          950: "#022c22",
        },
        // Surface colors — light mode with very subtle teal hint
        surface: {
          DEFAULT: "#f8fafa",
          raised: "#ffffff",
          overlay: "#f2f4f3",
          elevated: "#eaeceb",
          border: "#e5e7e6",
          "border-light": "#d4d7d5",
        },
        // Status colors
        status: {
          success: "#059669",
          error: "#dc2626",
          warning: "#d97706",
          info: "#2563eb",
        },
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "sans-serif"],
        mono: ["JetBrains Mono", "Fira Code", "monospace"],
      },
      fontSize: {
        display: ["2.25rem", { lineHeight: "1.2", letterSpacing: "-0.02em" }],
        heading: ["1.5rem", { lineHeight: "1.25", letterSpacing: "-0.01em" }],
        subheading: ["1.125rem", { lineHeight: "1.3", letterSpacing: "-0.01em" }],
        body: ["0.875rem", { lineHeight: "1.5" }],
        small: ["0.75rem", { lineHeight: "1.5" }],
        tiny: ["0.6875rem", { lineHeight: "1.4" }],
      },
      boxShadow: {
        "soft-sm": "0 1px 2px 0 rgba(0, 0, 0, 0.04)",
        soft: "0 1px 3px 0 rgba(0, 0, 0, 0.06), 0 1px 2px -1px rgba(0, 0, 0, 0.06)",
        "soft-md": "0 4px 6px -1px rgba(0, 0, 0, 0.07), 0 2px 4px -2px rgba(0, 0, 0, 0.05)",
        "soft-lg": "0 10px 15px -3px rgba(0, 0, 0, 0.08), 0 4px 6px -4px rgba(0, 0, 0, 0.04)",
      },
      spacing: {
        section: "96px",
        group: "48px",
        element: "24px",
        related: "12px",
        tight: "8px",
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
        card: "12px",
        button: "8px",
        input: "8px",
        badge: "6px",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};
export default config;
