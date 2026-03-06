import type { SVGProps } from "react";

export interface LogoProps extends SVGProps<SVGSVGElement> {
  /** Height in pixels or CSS value; width scales to preserve aspect (viewBox 116.88×48.49) */
  height?: number | string;
}

export function Logo({ height = 32, className, ...props }: LogoProps) {
  const h = typeof height === "number" ? `${height}px` : height;
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 116.88 48.49"
      aria-label="mnml trade"
      className={className}
      style={{ height: h, width: "auto" }}
      {...props}
    >
      <g>
        <path
          fill="#18181b"
          d="M35.29,11.65v25.2h-3.53v-17.28l-7.81,17.28h-3.02l-7.81-17.28v17.28h-3.53V11.65h3.53l9.32,20.12,9.32-20.12h3.53Z"
        />
        <path
          fill="#18181b"
          d="M57.83,11.65v25.2h-3.53l-13.32-18.83v18.83h-3.53V11.65h3.53l13.32,18.86V11.65h3.53Z"
        />
        <path
          fill="#18181b"
          d="M85.69,11.65v25.2h-3.53v-17.28l-7.81,17.28h-3.02l-7.81-17.28v17.28h-3.53V11.65h3.53l9.32,20.12,9.32-20.12h3.53Z"
        />
        <path
          fill="#18181b"
          d="M101.96,33.43v3.42h-14.11V11.65h3.53v21.78h10.58Z"
        />
        <path fill="#059669" d="M103.76,32.45h3.53v4.39h-3.53v-4.39Z" />
      </g>
      <path
        fill="#18181b"
        d="M116.88,48.49H0V0h116.88v48.49ZM4,44.49h108.88V4H4v40.49Z"
      />
    </svg>
  );
}
