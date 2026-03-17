import * as React from "react";

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {}

export const Card = React.forwardRef<HTMLDivElement, CardProps>(
  ({ className = "", ...props }, ref) => {
    return (
      <div
        ref={ref}
        className={`rounded-xl border border-zinc-200 bg-white shadow-sm ${className}`}
        {...props}
      />
    );
  },
);

Card.displayName = "Card";

export const CardHeader = React.forwardRef<HTMLDivElement, CardProps>(
  ({ className = "", ...props }, ref) => {
    return (
      <div
        ref={ref}
        className={`px-6 py-4 border-b border-zinc-100 ${className}`}
        {...props}
      />
    );
  },
);

CardHeader.displayName = "CardHeader";

export const CardContent = React.forwardRef<HTMLDivElement, CardProps>(
  ({ className = "", ...props }, ref) => {
    return (
      <div ref={ref} className={`px-6 py-4 ${className}`} {...props} />
    );
  },
);

CardContent.displayName = "CardContent";

export const CardFooter = React.forwardRef<HTMLDivElement, CardProps>(
  ({ className = "", ...props }, ref) => {
    return (
      <div
        ref={ref}
        className={`px-6 py-4 border-t border-zinc-100 ${className}`}
        {...props}
      />
    );
  },
);

CardFooter.displayName = "CardFooter";
