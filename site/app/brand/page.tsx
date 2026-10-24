import type { Metadata } from "next"
import { BrandStudio } from "./studio"

export const metadata: Metadata = {
  title: "Haven — A little presence. A lot of possibility.",
  description: "Meet the Haven identity: an expressive companion, a familiar H, and a quiet presence on your Mac. Explore the logo, app icons, menu bar icon, and motion.",
}

export default function BrandPage() {
  return <BrandStudio />
}
