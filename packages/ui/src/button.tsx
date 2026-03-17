import * as React from "react";

const variantClasses = {
  primary: "bg-primary-600 text-white hover:bg-primary-700",
  secondary: "bg-zinc-200 text-zinc-900 hover:bg-zinc-300",
  outline: "border border-zinc-300 text-zinc-700 hover:bg-zinc-50",
  ghost: "text-zinc-700 hover:bg-zinc-100",
  destructive: "bg-bearish text-white hover:bg-bearish-dark",
} as const;

const sizeClasses = {
  sm: "px-3 py-1.5 text-sm",
  md: "px-4 py-2 text-sm",
  lg: "px-6 py-3 text-base",
} as const;

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: keyof typeof variantClasses;
  size?: keyof typeof sizeClasses;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = "primary", size = "md", className = "", ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={`inline-flex items-center justify-center rounded-lg font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 disabled:pointer-events-none disabled:opacity-50 ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
        {...props}
      />
    );
  },
);

Button.displayName = "Button";
