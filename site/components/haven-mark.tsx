"use client"

import { useId } from "react"

const silhouette = "M72 28 C90 28 100 40 104 58 L110 84 C112 94 118 100 128 100 C138 100 144 94 146 84 L152 58 C156 40 166 28 184 28 C208 28 224 46 224 70 C224 86 216 104 216 128 C216 152 224 170 224 186 C224 210 208 228 184 228 C166 228 156 216 152 198 L146 172 C144 162 138 156 128 156 C118 156 112 162 110 172 L104 198 C100 216 90 228 72 228 C48 228 32 210 32 186 C32 170 40 152 40 128 C40 104 32 86 32 70 C32 46 48 28 72 28 Z"

export type HavenExpression = "idle" | "working" | "done" | "attention"

/** The same organic H silhouette is used on the web, in the app, and in the menu bar. */
export function HavenMark({
  className,
  animated = false,
  expression = "idle",
}: {
  className?: string
  animated?: boolean
  expression?: HavenExpression
}) {
  const maskId = `haven-eyes-${useId().replace(/:/g, "")}`

  return (
    <svg
      className={`haven-mark ${className ?? ""}`}
      data-animated={animated}
      data-expression={expression}
      viewBox="0 0 256 256"
      fill="currentColor"
      aria-hidden="true"
      focusable="false"
    >
      <defs>
        <mask id={maskId} maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256">
          <rect width="256" height="256" fill="white" />
          {expression === "done" ? (
            <g fill="none" stroke="black" strokeWidth="8" strokeLinecap="round">
              <path d="M104 129 Q112 117 120 129" />
              <path d="M136 129 Q144 117 152 129" />
            </g>
          ) : expression === "working" ? (
            <g fill="black">
              <rect className="haven-mark-wave haven-mark-wave-1" x="103" y="121" width="10" height="14" rx="5" />
              <rect className="haven-mark-wave haven-mark-wave-2" x="123" y="115" width="10" height="26" rx="5" />
              <rect className="haven-mark-wave haven-mark-wave-3" x="143" y="121" width="10" height="14" rx="5" />
            </g>
          ) : expression === "attention" ? (
            <g fill="black">
              <circle cx="111" cy="128" r="9" />
              <circle cx="145" cy="128" r="9" />
            </g>
          ) : (
            <g className="haven-mark-eyes" fill="black">
              <rect x="106" y="117" width="12" height="22" rx="6" />
              <rect x="138" y="117" width="12" height="22" rx="6" />
            </g>
          )}
        </mask>
      </defs>
      <g className="haven-mark-body">
        <path d={silhouette} mask={`url(#${maskId})`} />
      </g>
    </svg>
  )
}

/** Silhouette-only template with the same optical crop as the native menu icon. */
export function HavenMenuMark({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="16 16 224 224" fill="currentColor" aria-hidden="true" focusable="false">
      <path d={silhouette} />
    </svg>
  )
}
