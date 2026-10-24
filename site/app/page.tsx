import { Code2, Globe, Laptop, Layers, Plug, BookOpen, Fingerprint, KeyRound, EyeOff, CornerDownLeft } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion"
import { HavenMark } from "@/components/haven-mark"
import { HeroDemo } from "@/components/landing/hero-demo"
import { StatusPill } from "@/components/landing/status-pill"

const REPO = "https://github.com/Gokulakrishnxn/Haven"

const CAPABILITIES = [
  { icon: Code2, t: "Code", d: "Hand off a review, trace an error, or change a component. Haven brings the editor and terminal context with it." },
  { icon: Globe, t: "Browser", d: "Work in your own signed-in Chrome, only on the sites you connect." },
  { icon: Laptop, t: "The whole Mac", d: "Windows, controls and files become something an agent can read and act on, with your permission." },
  { icon: Plug, t: "MCP servers", d: "Attach exactly the tools a task needs. Nothing lingers." },
  { icon: BookOpen, t: "Skills", d: "Give a task a playbook. Remove it when the task ends." },
  { icon: Layers, t: "Parallel runs", d: "Start the next task without waiting. Each one runs on its own." },
]

const SECURITY = [
  { icon: KeyRound, t: "Keychain only", d: "Credentials never leave macOS Keychain. Haven doesn’t keep a copy." },
  { icon: Fingerprint, t: "Touch ID, every time", d: "The agent asks for a login for a specific site and task. You approve it with a touch." },
  { icon: EyeOff, t: "Never in context", d: "Haven fills the verified field directly. The value never reaches the model. Each use is logged." },
]

const FAQ = [
  { q: "What is Haven?", a: "A native Mac app that puts your AI agent one shortcut away. You invoke it from whatever you are doing, point at what you mean, and it works in the background." },
  { q: "Which agents does it work with?", a: "Claude Code and Codex first, with Grok next. Haven uses the agent CLIs and subscriptions already on your Mac. It does not ship a model of its own." },
  { q: "What does “point at anything” mean?", a: "In Annotate mode you click an element, drag a region, or select text, and leave a note. Haven turns that into structured context an agent can act on precisely, instead of a description like “the blue button on the left”." },
  { q: "Will agents see my passwords?", a: "No. By design, credentials live in macOS Keychain. When an agent needs to sign in, you approve with Touch ID and Haven fills the verified field directly. The value never enters the model’s context." },
  { q: "What can an agent do without asking?", a: "Reading is automatic. Writing, sending, deleting and spending ask first. You can review every sensitive action afterward in the audit log." },
  { q: "Does it work on a Mac without a notch?", a: "Yes. Haven’s status lives in a small pill. On Macs with a notch, it can extend from the notch instead." },
  { q: "Is my data sent to Haven?", a: "No. Haven runs locally and has no server in the data path. What reaches a model is what the agent you chose sends." },
  { q: "What permissions does it need?", a: "Only what a feature needs, asked for at the moment you use it. Haven works without them, with fewer abilities." },
  { q: "Is it ready?", a: "Not yet. Haven is in early development. The shortcut, context capture, background tasks, status pill and task window work today. Annotation, the credential vault and the rest are being built in the open." },
]

const eyebrow = "mb-4 text-[15px] font-semibold text-muted-foreground"
const section = "mx-auto max-w-5xl px-6 py-20 md:py-32"
const h2 = "text-4xl font-bold leading-[1.05] md:text-6xl"

export default function Home() {
  return (
    <>
      <header className="sticky top-0 z-20 flex h-13 items-center justify-between border-b bg-background/70 px-6 backdrop-blur-xl">
        <a href="#top" className="flex items-center gap-2 text-lg font-bold tracking-tight">
          <HavenMark className="size-5" /> Haven
        </a>
        <nav className="flex items-center gap-6 text-[13px] text-muted-foreground">
          <a className="hidden hover:text-foreground sm:block" href="#annotate">Annotate</a>
          <a className="hidden hover:text-foreground sm:block" href="#security">Security</a>
          <a className="hidden hover:text-foreground sm:block" href="#faq">FAQ</a>
          <Button asChild size="sm" className="rounded-full px-3.5"><a href={REPO}>Get Haven</a></Button>
        </nav>
      </header>

      <main id="top">
        <section className="mx-auto max-w-5xl px-6 pb-16 pt-20 text-center md:pt-24">
          <p className={eyebrow}>Introducing Haven</p>
          <h1 className="text-5xl font-bold leading-[1.02] md:text-8xl">
            Point at anything.<br />
            <span className="bg-gradient-to-r from-blue-500 via-violet-500 to-pink-500 bg-clip-text text-transparent">Haven does the rest.</span>
          </h1>
          <p className="mx-auto mt-6 max-w-xl text-xl leading-snug text-muted-foreground md:text-2xl">
            One shortcut, any app. Say what you want, and your agent gets it done while you keep working.
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-7">
            <Button asChild size="lg" className="h-11 rounded-full px-6 text-base"><a href={REPO}>Download for Mac</a></Button>
            <a href="#annotate" className="text-base text-blue-600 hover:underline dark:text-blue-400">See how it works ›</a>
          </div>
          <p className="mt-3.5 text-[13px] text-muted-foreground">Early preview · macOS 13 or later</p>
          <HeroDemo />
        </section>

        <section className={`${section} text-center`}>
          <h2 className={h2}>
            Your Mac has a new gesture.<br />
            <span className="text-muted-foreground">It’s called pointing.</span>
          </h2>
          <p className="mx-auto mt-7 max-w-xl text-xl text-muted-foreground">
            You’ve never had to explain a button to a friend sitting next to you. You point. Haven gives your
            agent the same ability, across every app on your Mac.
          </p>
        </section>

        <section className={`${section} grid items-center gap-10 md:grid-cols-2 md:gap-16`} id="shortcut">
          <div>
            <p className={eyebrow}>Anywhere</p>
            <h2 className={`${h2} mb-5`}>Press. Ask. Done.</h2>
            <p className="text-lg text-muted-foreground">
              Haven doesn’t live in a tab. Press ⌥Space in any app and it opens right there, already holding
              what you were looking at. Type a sentence. Close it. That’s the whole interface.
            </p>
          </div>
          <Card className="min-h-64 justify-center rounded-3xl p-3" aria-hidden="true">
            <CardContent className="space-y-3">
              <small className="text-xs text-muted-foreground">Safari · “Q3 vendor invoices”</small>
              <p className="text-xl">Summarize these and flag anything over $10k</p>
              <div className="flex justify-between text-xs text-muted-foreground">
                <span>Claude Code ▾</span>
                <span className="inline-flex items-center gap-1">Run <CornerDownLeft className="size-3" /></span>
              </div>
            </CardContent>
          </Card>
        </section>

        <section className={`${section} grid items-center gap-10 md:grid-cols-2 md:gap-16`} id="annotate">
          <div className="md:order-2">
            <p className={eyebrow}>Annotate</p>
            <h2 className={`${h2} mb-5`}>Show it. Don’t describe it.</h2>
            <p className="text-lg text-muted-foreground">
              Click an element. Drag across a region. Leave a note. Haven captures exactly what you meant,
              with its identity, text, position and a picture, and hands your agent a precise brief. The
              wrong button never gets fixed again.
            </p>
          </div>
          <Card className="min-h-64 justify-center rounded-3xl p-3 md:order-1" aria-hidden="true">
            <CardContent className="space-y-3">
              {["Button is too small", "Heading doesn’t match the spec", "Remove this banner"].map((n, k) => (
                <div key={n} className="flex items-center gap-3">
                  <b className="grid size-6 flex-none place-items-center rounded-full bg-orange-500 text-[13px] text-white">{k + 1}</b>
                  {n}
                </div>
              ))}
              <code className="block pt-2 font-mono text-xs text-muted-foreground">main &gt; form button.primary</code>
            </CardContent>
          </Card>
        </section>

        <section className={`${section} grid items-center gap-10 md:grid-cols-2 md:gap-16`} id="detach">
          <div>
            <p className={eyebrow}>Detach</p>
            <h2 className={`${h2} mb-5`}>Let it go.</h2>
            <p className="text-lg text-muted-foreground">
              Close the window and the task keeps running, quietly, in a small pill at the top of your
              screen. Start another. Haven only speaks up when it needs you or when it’s finished.
            </p>
          </div>
          <Card className="min-h-64 items-center justify-center gap-4 rounded-3xl" aria-hidden="true">
            <StatusPill state="working">2 tasks working</StatusPill>
            <StatusPill state="approve">Approve to continue</StatusPill>
            <StatusPill state="done">Done</StatusPill>
          </Card>
        </section>

        <section className={`${section} text-center`}>
          <h2 className={h2}>Bring your own brain.</h2>
          <p className="mx-auto mt-7 max-w-xl text-xl text-muted-foreground">
            Haven doesn’t sell you a model. It works with the agents you already use, Claude Code and Codex
            today, with Grok next, on the subscriptions you already have. Pick one per task. Switch any time.
          </p>
        </section>

        <section className={`${section} text-center`} id="security">
          <p className={eyebrow}>Security</p>
          <h2 className={h2}>Your passwords stay yours.</h2>
          <p className="mx-auto mt-5 max-w-xl text-xl text-muted-foreground">
            Agents are powerful. That’s exactly why they should never hold your keys.
          </p>
          <div className="mt-14 grid gap-4 text-left md:grid-cols-3">
            {SECURITY.map(({ icon: Icon, t, d }) => (
              <Card key={t} className="rounded-3xl p-3">
                <CardHeader><Icon className="mb-2 size-6" /><CardTitle className="text-xl">{t}</CardTitle></CardHeader>
                <CardContent><CardDescription className="text-base">{d}</CardDescription></CardContent>
              </Card>
            ))}
          </div>
        </section>

        <section className={`${section} text-center`}>
          <h2 className={h2}>Not another tab.</h2>
          <p className="mx-auto mt-5 max-w-xl text-xl text-muted-foreground">Attach what a task needs, and nothing more.</p>
          <div className="mt-14 grid gap-4 text-left md:grid-cols-3">
            {CAPABILITIES.map(({ icon: Icon, t, d }) => (
              <Card key={t} className="rounded-3xl p-3">
                <CardHeader><Icon className="mb-2 size-6" /><CardTitle className="text-xl">{t}</CardTitle></CardHeader>
                <CardContent><CardDescription className="text-base">{d}</CardDescription></CardContent>
              </Card>
            ))}
          </div>
        </section>

        <section className={`${section} max-w-3xl`} id="faq">
          <h2 className={`${h2} mb-12 text-center`}>Questions</h2>
          <Accordion type="single" collapsible>
            {FAQ.map((f) => (
              <AccordionItem key={f.q} value={f.q}>
                <AccordionTrigger>{f.q}</AccordionTrigger>
                <AccordionContent className="text-base">{f.a}</AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </section>

        <section className={`${section} pb-36 text-center`}>
          <h2 className={h2}>
            Work stays here.<br />
            <span className="bg-gradient-to-r from-blue-500 via-violet-500 to-pink-500 bg-clip-text text-transparent">Agents come to you.</span>
          </h2>
          <div className="mt-8">
            <Button asChild size="lg" className="h-11 rounded-full px-6 text-base"><a href={REPO}>Download for Mac</a></Button>
          </div>
          <p className="mt-3.5 text-[13px] text-muted-foreground">Early preview · open source</p>
        </section>
      </main>

      <footer className="mx-auto flex max-w-5xl flex-wrap justify-between gap-3 border-t px-6 pb-12 pt-7 text-[13px] text-muted-foreground">
        <span>© 2026 Haven</span>
        <span className="flex gap-6">
          <a className="hover:text-foreground" href="#security">Security</a>
          <a className="hover:text-foreground" href="#faq">FAQ</a>
          <a className="hover:text-foreground" href={REPO}>GitHub</a>
        </span>
      </footer>
    </>
  )
}
