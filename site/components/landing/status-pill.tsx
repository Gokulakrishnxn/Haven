import { cn } from "@/lib/utils"

const DOT = { working: "bg-working animate-pulse", approve: "bg-approve", done: "bg-done" } as const

export function StatusPill({ state, children, className }: { state: keyof typeof DOT; children: React.ReactNode; className?: string }) {
  return (
    <span className={cn("inline-flex items-center gap-2 rounded-full border bg-card/80 px-4 py-1.5 text-[13px] font-medium shadow-sm backdrop-blur", className)}>
      <i className={cn("size-2 rounded-full", DOT[state])} />
      {children}
    </span>
  )
}
