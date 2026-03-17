/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: "class",
  content: [
    "./app/**/*.{js,jsx,ts,tsx}",
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        primary: {
          50: "#f0f4ff",
          100: "#dbe4ff",
          200: "#bac8ff",
          300: "#91a7ff",
          400: "#748ffc",
          500: "#5c7cfa",
          600: "#4c6ef5",
          700: "#4263eb",
          800: "#3b5bdb",
          900: "#364fc7",
        },
        bullish: {
          DEFAULT: "#22c55e",
          light: "#86efac",
          dark: "#15803d",
        },
        bearish: {
          DEFAULT: "#ef4444",
          light: "#fca5a5",
          dark: "#b91c1c",
        },
      },
      fontFamily: {
        sans: ["System"],
        mono: ["SpaceMono"],
      },
    },
  },
  plugins: [],
};
