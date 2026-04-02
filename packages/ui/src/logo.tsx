import type { SVGProps } from "react";

export interface LogoProps extends SVGProps<SVGSVGElement> {
  /** Height in pixels or CSS value; width scales to preserve aspect ratio */
  height?: number | string;
  /** When true, use logo_light_1-style fills (light text on dark UI). When false, logo_2-style (dark text on light UI). */
  dark?: boolean;
}

/** Shared wordmark geometry: logo_2.svg / logo_light_1.svg (viewBox 0 0 250.89 64.7) */
const VIEWBOX = "0 0 250.89 64.7";
const PATHS = {
  text1: "M66,0v64.7h-9.06V20.34l-20.06,44.37h-7.76L9.06,20.34v44.37H0V0h9.06l23.94,51.67L56.94,0h9.06Z",
  text2: "M123.87,0v64.7h-9.06l-34.2-48.34v48.34h-9.06V0h9.06l34.2,48.44V0h9.06Z",
  text3: "M195.42,0v64.7h-9.06V20.34l-20.06,44.37h-7.76l-20.06-44.37v44.37h-9.06V0h9.06l23.94,51.67L186.36,0h9.06Z",
  text4: "M237.21,55.92v8.78h-36.23V0h9.06v55.92h27.18Z",
  dot: "M241.83,55.86h9.06v8.85h-9.06v-8.85Z",
} as const;

/** Light UI (logo_2): zinc-900 text */
const FILL_LIGHT_UI = { text: "#18181b", accent: "#059669" };
/** Dark UI (logo_light_1): zinc-50 text per asset */
const FILL_DARK_UI = { text: "#fafafa", accent: "#059669" };

export function Logo({ height = 24, dark = false, className, ...props }: LogoProps) {
  const h = typeof height === "number" ? `${height}px` : height;
  const { text, accent } = dark ? FILL_DARK_UI : FILL_LIGHT_UI;

  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox={VIEWBOX}
      aria-label="mnml trade"
      className={className}
      style={{ height: h, width: "auto" }}
      {...props}
    >
      <g>
        <path fill={text} d={PATHS.text1} />
        <path fill={text} d={PATHS.text2} />
        <path fill={text} d={PATHS.text3} />
        <path fill={text} d={PATHS.text4} />
        <path fill={accent} d={PATHS.dot} />
      </g>
    </svg>
  );
}
