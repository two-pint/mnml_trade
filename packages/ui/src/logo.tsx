import type { SVGProps } from "react";

export interface LogoProps extends SVGProps<SVGSVGElement> {
  /** Height in pixels or CSS value; width scales to preserve aspect (viewBox 116.88×48.49) */
  height?: number | string;
  /** When true, use light variant (e.g. for dark mode). When false/undefined, use dark variant. */
  dark?: boolean;
}

const VIEWBOX = "0 0 116.88 48.49";
const PATHS = {
  text1: "M35.29,11.65v25.2h-3.53v-17.28l-7.81,17.28h-3.02l-7.81-17.28v17.28h-3.53V11.65h3.53l9.32,20.12,9.32-20.12h3.53Z",
  text2: "M57.83,11.65v25.2h-3.53l-13.32-18.83v18.83h-3.53V11.65h3.53l13.32,18.86V11.65h3.53Z",
  text3: "M85.69,11.65v25.2h-3.53v-17.28l-7.81,17.28h-3.02l-7.81-17.28v17.28h-3.53V11.65h3.53l9.32,20.12,9.32-20.12h3.53Z",
  text4: "M101.96,33.43v3.42h-14.11V11.65h3.53v21.78h10.58Z",
  dot: "M103.76,32.45h3.53v4.39h-3.53v-4.39Z",
  frame: "M116.88,48.49H0V0h116.88v48.49ZM4,44.49h108.88V4H4v40.49Z",
} as const;

export function Logo({ height = 32, dark = false, className, ...props }: LogoProps) {
  const h = typeof height === "number" ? `${height}px` : height;
  const textFill = dark ? "#e4e4e7" : "#18181b";
  const frameFill = dark ? "#e4e4e7" : "#18181b";

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
        <path fill={textFill} d={PATHS.text1} />
        <path fill={textFill} d={PATHS.text2} />
        <path fill={textFill} d={PATHS.text3} />
        <path fill={textFill} d={PATHS.text4} />
        <path fill="#059669" d={PATHS.dot} />
      </g>
      <path fill={frameFill} d={PATHS.frame} />
    </svg>
  );
}
