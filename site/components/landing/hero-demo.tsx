"use client"

import { useEffect, useState } from "react"
import { AnimatePresence, motion } from "motion/react"
import { CornerDownLeft } from "lucide-react"
import { StatusPill } from "./status-pill"

const STEPS = [
  { caption: "Press ⌥Space anywhere", composer: true, pin: false, pill: null },
  { caption: "Point at what you mean", composer: true, pin: true, pill: null },
  { caption: "Keep working", composer: false, pin: true, pill: "working" },
  { caption: "Approve when asked", composer: false, pin: true, pill: "approve" },
  { caption: "Done", composer: false, pin: true, pill: "done" },
] as const

const PILL_TEXT = { working: "1 task working", approve: "Approve to continue", done: "Done" } as const

export function HeroDemo() {
  const [i, setI] = useState(0)

  useEffect(() => {
    // Reduced motion: stay on the first frame instead of cycling.
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    const t = setInterval(() => setI((n) => (n + 1) % STEPS.length), 2600)
    return () => clearInterval(t)
  }, [])

  const s = STEPS[i]

  return (
    <div
      role="img"
      aria-label="Preview: press the shortcut, point at a button, send a request, and watch it complete from a status pill"
      className="relative mx-auto mt-16 aspect-[16/10] w-full max-w-4xl overflow-hidden rounded-3xl border bg-gradient-to-br from-slate-700 via-slate-900 to-black text-left text-white shadow-2xl"
    >
      <div className="flex gap-4 bg-white/10 px-4 py-1.5 text-xs backdrop-blur">
        <span></span><b>Haven</b><span className="flex-1" /><span>⌥Space</span>
      </div>

      <div className="absolute inset-x-[7%] bottom-[8%] top-[14%] overflow-hidden rounded-xl bg-white text-neutral-900 shadow-2xl">
        <div className="flex items-center gap-1.5 bg-neutral-200 px-3.5 py-2.5 text-[11px] text-neutral-500">
          <i className="size-2.5 rounded-full bg-[#ff5f57]" /><i className="size-2.5 rounded-full bg-[#febc2e]" /><i className="size-2.5 rounded-full bg-[#28c840]" />
          <span className="ml-3">app.example.com/settings</span>
        </div>
        <div className="relative space-y-3 p-[6%]">
          <h4 className="text-[clamp(14px,2.2vw,22px)] font-semibold">Account</h4>
          <div className="h-3 w-[70%] rounded-md bg-neutral-200" />
          <div className="h-3 w-[45%] rounded-md bg-neutral-200" />
          <div className="relative inline-block rounded-lg bg-blue-600 px-[18px] py-1.5 text-xs text-white">
            Save
            <motion.em
              initial={false}
              animate={{ scale: s.pin ? 1 : 0 }}
              transition={{ type: "spring", stiffness: 500, damping: 20 }}
              className="absolute -right-2.5 -top-2.5 grid size-5 place-items-center rounded-full bg-orange-500 text-[11px] not-italic"
            >
              1
            </motion.em>
          </div>
        </div>
      </div>

      <AnimatePresence>
        {s.composer && (
          <motion.div
            key="composer"
            initial={{ opacity: 0, y: 10, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 6 }}
            transition={{ duration: 0.28, ease: "easeOut" }}
            className="absolute left-1/2 top-[34%] w-[min(70%,520px)] -translate-x-1/2 rounded-2xl border border-white/15 bg-neutral-800/70 p-4 shadow-2xl backdrop-blur-xl"
          >
            <small className="text-xs text-white/60">Chrome · Save button</small>
            <p className="mt-1.5 text-[clamp(13px,2vw,19px)]">{s.pin ? "Make this 44pt tall and match the spec" : "What should Haven do?"}</p>
            <div className="mt-2 flex justify-between text-xs text-white/60">
              <span>Claude Code ▾</span>
              <span className="inline-flex items-center gap-1">Run <CornerDownLeft className="size-3" /></span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="absolute left-1/2 top-1 -translate-x-1/2">
        <AnimatePresence mode="wait">
          {s.pill && (
            <motion.div key={s.pill} initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
              <StatusPill state={s.pill} className="border-white/15 bg-neutral-900/85 text-white">{PILL_TEXT[s.pill]}</StatusPill>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <p className="absolute bottom-3 w-full text-center text-[13px] text-white/75" aria-live="polite">{s.caption}</p>
    </div>
  )
}
