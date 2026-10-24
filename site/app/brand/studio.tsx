"use client"

import { useState } from "react"
import Link from "next/link"
import Image from "next/image"
import { ArrowDown, ArrowUpRight, BatteryFull, Check, Download, Pause, Play, Wifi } from "lucide-react"
import { HavenMark, HavenMenuMark, type HavenExpression } from "@/components/haven-mark"
import styles from "./studio.module.css"

const EXPRESSIONS: { id: HavenExpression; label: string; description: string }[] = [
  { id: "idle", label: "Here", description: "A gentle breath. An occasional blink. Ready when you are." },
  { id: "working", label: "Working", description: "A little rhythm while your agent takes care of things." },
  { id: "done", label: "Done", description: "A small, happy nod. Your task is ready." },
  { id: "attention", label: "Needs you", description: "Eyes open. Waiting for your attention, without the noise." },
]

const ICONS = [
  { color: "cyan", title: "Daylight", hex: "#00D7F4", label: "The original" },
  { color: "mint", title: "Lagoon", hex: "#00E9BE", label: "A fresh perspective" },
  { color: "coral", title: "Daybreak", hex: "#FF6080", label: "A warmer welcome" },
  { color: "gold", title: "Sunbeam", hex: "#F5D719", label: "A little optimism" },
]

const DOWNLOADS = [
  { title: "The logo", detail: "Light + dark · SVG", href: "/brand/haven-mark-dark.svg", light: "/brand/haven-mark-light.svg" },
  { title: "The wordmark", detail: "Light + dark · SVG", href: "/brand/haven-wordmark-dark.svg", light: "/brand/haven-wordmark-light.svg" },
  { title: "Mac app icon", detail: "All sizes · ICNS", href: "/brand/Haven.icns" },
  { title: "Menu bar icon", detail: "Monochrome · SVG", href: "/brand/haven-menu-template.svg" },
  { title: "Animated logo", detail: "Breath + blink · SVG", href: "/brand/haven-mark-animated.svg" },
]

export function BrandStudio() {
  const [playing, setPlaying] = useState(true)
  const [expression, setExpression] = useState<HavenExpression>("idle")
  const activeExpression = EXPRESSIONS.find((item) => item.id === expression)!

  return (
    <div className={styles.studio} data-motion={playing ? "playing" : "paused"}>
      <header className={styles.header}>
        <Link href="/" className={styles.brandLink} aria-label="Haven home"><HavenMark className={styles.navMark} /><span>Haven</span></Link>
        <nav className={styles.nav} aria-label="Brand navigation">
          <a href="#identity">Identity</a>
          <a href="#motion">In motion</a>
          <a href="#downloads" className={styles.navDownload}>Get the assets <ArrowUpRight size={15} /></a>
        </nav>
      </header>

      <main>
        <section className={styles.intro}>
          <p className={styles.eyebrow}>THE HAVEN IDENTITY <span>01 — 2026</span></p>
          <div className={styles.introRow}>
            <h1>A little presence.<br /><span>A lot of possibility.</span></h1>
            <p>Your agent, right beside you.<br />Meet a familiar face for a new way to work.</p>
          </div>
        </section>

        <section className={styles.hero} id="identity" aria-label="Haven logo on a vivid blue and coral background">
          <div className={styles.atmosphere} />
          <div className={styles.grain} />
          <div className={styles.heroTop}><span>QUIETLY CAPABLE. ALWAYS HERE.</span><span>A COMPANION FOR YOUR MAC</span></div>
          <div className={styles.heroIdentity}>
            <HavenMark className={styles.heroMark} animated={playing} />
            <span className={styles.heroWordmark}>Haven</span>
          </div>
          <div className={styles.heroBottom}><span>Point at anything.<br />Haven does the rest.</span><a href="#icons" aria-label="Explore the app icons"><ArrowDown size={24} /></a></div>
        </section>

        <section className={styles.story}>
          <p className={styles.eyebrow}>A FAMILIAR SHAPE. A LITTLE SOUL.</p>
          <h2>An H that feels<br />like someone’s here.</h2>
          <p>Soft edges. Open arms. Two curious eyes. Haven’s mark brings a little warmth to a powerful idea: an agent that joins you in your work, then quietly gets on with it.</p>
        </section>

        <section className={styles.iconSection} id="icons">
          <div className={styles.sectionHeading}><div><p className={styles.eyebrow}>01 / ON YOUR MAC</p><h2>A bright spot in your day.</h2></div><span>FOUR WAYS TO FEEL AT HOME</span></div>
          <div className={styles.iconGrid}>
            {ICONS.map((icon) => (
              <article className={styles.iconItem} key={icon.color}>
                <a className={styles.iconDownload} href={`/brand/haven-app-${icon.color}.png`} download aria-label={`Download ${icon.title} app icon PNG`}>
                  <Image src={`/brand/haven-app-${icon.color}.svg`} width={256} height={256} className={styles.appIcon} alt={`Haven ${icon.title} icon: dark organic H on a glossy ${icon.color} background`} unoptimized />
                  <span className={styles.iconDownloadHint}><Download size={15} /> PNG</span>
                </a>
                <div className={styles.iconCaption}><h3>{icon.title}</h3><span>{icon.hex}</span></div>
                <p>{icon.label}</p>
              </article>
            ))}
          </div>
        </section>

        <section className={styles.motionSection} id="motion">
          <div className={styles.motionCopy}>
            <p className={styles.eyebrow}>02 / A LITTLE LIFE</p>
            <h2>Present.<br />Never pushy.</h2>
            <p>A quiet breath when it’s here. A gentle rhythm when it’s working. Just enough expression to feel like a companion.</p>
            <button className={styles.motionToggle} onClick={() => setPlaying(!playing)} aria-pressed={!playing}>{playing ? <Pause size={14} fill="currentColor" /> : <Play size={14} fill="currentColor" />}{playing ? "Pause all motion" : "Play motion"}</button>
            <small>Respects your device’s reduced motion setting.</small>
          </div>
          <div className={styles.motionPreview}>
            <div className={styles.motionStage}>
              <span className={styles.liveLabel}><i className={playing ? styles.liveDot : styles.pausedDot} />{playing ? "LIVE PREVIEW" : "MOTION PAUSED"}</span>
              <HavenMark className={styles.motionMark} expression={expression} animated={playing} />
              <p aria-live="polite">{activeExpression.description}</p>
            </div>
            <div className={styles.expressionTabs} role="group" aria-label="Logo expression">
              {EXPRESSIONS.map((item) => <button key={item.id} aria-pressed={expression === item.id} onClick={() => setExpression(item.id)}>{item.label}</button>)}
            </div>
          </div>
        </section>

        <section className={styles.menuSection}>
          <div className={styles.sectionHeading}><div><p className={styles.eyebrow}>03 / ALWAYS CLOSE</p><h2>Small, but unmistakably Haven.</h2></div><span>MADE FOR THE MENU BAR</span></div>
          <div className={styles.menuGrid}>
            <div className={`${styles.desktopPreview} ${styles.desktopLight}`}>
              <div className={styles.macMenu} aria-label="Light macOS menu bar preview"><span className={styles.menuApp}>Finder</span><span>File</span><span>Edit</span><div className={styles.menuRight}><HavenMenuMark className={styles.menuMark} /><Wifi size={15} /><BatteryFull size={19} /><span>9:41</span></div></div>
              <div className={styles.desktopLabel}><span>Light appearance</span><span>18 × 18 pt</span></div>
            </div>
            <div className={`${styles.desktopPreview} ${styles.desktopDark}`}>
              <div className={styles.macMenu} aria-label="Dark macOS menu bar preview"><span className={styles.menuApp}>Finder</span><span>File</span><span>Edit</span><div className={styles.menuRight}><HavenMenuMark className={styles.menuMark} /><Wifi size={15} /><BatteryFull size={19} /><span>9:41</span></div></div>
              <div className={styles.desktopLabel}><span>Dark appearance</span><span>18 × 18 pt</span></div>
            </div>
          </div>
          <p className={styles.menuNote}><Check size={15} /> One clear silhouette. A monochrome template that follows your Mac’s appearance.</p>
        </section>

        <section className={styles.downloadSection} id="downloads">
          <div className={styles.downloadIntro}><p className={styles.eyebrow}>04 / MAKE YOURSELF AT HOME</p><h2>Everything Haven.</h2><p>The complete identity, ready for the real world.</p><a href="/brand/brand-kit.zip" download className={styles.kitButton}>Download the brand kit <ArrowDown size={17} /></a></div>
          <div className={styles.downloadList}>
            {DOWNLOADS.map((asset) => <div className={styles.downloadRow} key={asset.title}><div><h3>{asset.title}</h3><p>{asset.detail}</p></div><div className={styles.assetLinks}>{asset.light ? <><a href={asset.href} download aria-label={`Download dark ${asset.title.toLowerCase()}`}>Dark <Download size={14} /></a><a href={asset.light} download aria-label={`Download light ${asset.title.toLowerCase()}`}>Light <Download size={14} /></a></> : <a href={asset.href} download aria-label={`Download ${asset.title.toLowerCase()}`}><Download size={17} /></a>}</div></div>)}
          </div>
        </section>
      </main>
      <footer className={styles.footer}><Link href="/" className={styles.brandLink}><HavenMark className={styles.navMark} /><span>Haven</span></Link><span>A little more human. A little more possible.</span><a href="https://github.com/Gokulakrishnxn/Haven">Built in the open <ArrowUpRight size={14} /></a></footer>
    </div>
  )
}
