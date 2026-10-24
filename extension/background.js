// Haven browser bridge.
//
// Connects to the Haven app on this Mac (ws://127.0.0.1:48731) and carries out page-level commands for
// agents: list tabs, navigate, snapshot, click, type, select, scroll, extract text, screenshot.
//
// Safety:
//  - Haven only talks to this extension after the pairing token matches.
//  - Chrome itself enforces "only sites you connect": commands run only on origins the person granted
//    from the popup (optional host permissions). Anything else is refused.
//  - Password fields are never read and never typed into. Logins go through Haven's vault instead.

const PORT = 48731;
const VERSION = "0.1.0";
let socket = null;
let pingTimer = null;

async function connect() {
  if (socket && socket.readyState <= WebSocket.OPEN) return;
  const { token } = await chrome.storage.local.get("token");
  if (!token) return setStatus("Not paired. Open the extension options and paste the pairing code from Haven.");
  try {
    socket = new WebSocket(`ws://127.0.0.1:${PORT}`);
  } catch (e) {
    return setStatus("Could not reach Haven.");
  }
  socket.onopen = () => {
    socket.send(JSON.stringify({ type: "hello", token, version: VERSION }));
    clearInterval(pingTimer);
    // Messages keep the service worker alive.
    pingTimer = setInterval(() => socket?.readyState === WebSocket.OPEN && socket.send(JSON.stringify({ type: "ping" })), 20000);
  };
  socket.onmessage = async (event) => {
    let msg;
    try { msg = JSON.parse(event.data); } catch { return; }
    if (msg.type === "welcome") return setStatus("Connected to Haven.");
    if (msg.type === "rejected") return setStatus("Haven rejected the pairing code. Copy it again from Haven > Settings > Browser.");
    if (!msg.id || !msg.cmd) return;
    let result;
    try { result = await handle(msg.cmd, msg.args || {}); }
    catch (e) { result = { ok: false, message: String(e && e.message || e) }; }
    if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ id: msg.id, ...result }));
  };
  socket.onclose = () => { clearInterval(pingTimer); socket = null; setStatus("Waiting for Haven."); };
  socket.onerror = () => {};
}

function setStatus(text) { chrome.storage.session.set({ status: text }).catch(() => {}); }

chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
chrome.alarms.create("reconnect", { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener((a) => a.name === "reconnect" && connect());
chrome.storage.onChanged.addListener((changes) => { if (changes.token) { socket?.close(); connect(); } });
connect();

// ---------- Commands ----------

const NOT_CONNECTED = (host) =>
  `${host} is not connected to Haven. Ask the person to open the Haven extension on that site and choose Connect this site.`;

async function connected(url) {
  try {
    const u = new URL(url);
    if (!/^https?:$/.test(u.protocol)) return false;
    return await chrome.permissions.contains({ origins: [`${u.origin}/*`] });
  } catch { return false; }
}

async function targetTab(args) {
  if (args.tab) {
    return await chrome.tabs.get(Number(args.tab));
  }
  const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  if (!tab) throw new Error("No browser tab is active.");
  return tab;
}

async function allowedTab(args) {
  const tab = await targetTab(args);
  if (!(await connected(tab.url || ""))) {
    let host = "This site";
    try { host = new URL(tab.url).host; } catch {}
    throw new Error(NOT_CONNECTED(host));
  }
  return tab;
}

async function run(tab, func, fnArgs = []) {
  const [res] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func, args: fnArgs });
  return res?.result;
}

async function handle(cmd, args) {
  switch (cmd) {
    case "status": {
      const origins = (await chrome.permissions.getAll()).origins || [];
      return { ok: true, message: `Connected. Sites you have connected: ${origins.length ? origins.join(", ") : "none yet"}.` };
    }
    case "list-tabs": {
      const tabs = await chrome.tabs.query({});
      const lines = [];
      for (const t of tabs) {
        const ok = await connected(t.url || "");
        let host = "";
        try { host = new URL(t.url).host; } catch {}
        // Titles and addresses of sites that are not connected stay private.
        lines.push(`id=${t.id}${t.active ? " [active]" : ""} ${ok ? `${host} "${(t.title || "").slice(0, 80)}"` : "(not connected)"}`);
      }
      return { ok: true, message: lines.join("\n") || "No tabs." };
    }
    case "open-tab": {
      if (!(await connected(args.url || ""))) return { ok: false, message: NOT_CONNECTED(hostOf(args.url)) };
      const tab = await chrome.tabs.create({ url: args.url, active: true });
      return { ok: true, message: `Opened tab id=${tab.id}.` };
    }
    case "activate-tab": {
      const tab = await targetTab(args);
      await chrome.tabs.update(tab.id, { active: true });
      await chrome.windows.update(tab.windowId, { focused: true });
      return { ok: true, message: `Activated tab id=${tab.id}.` };
    }
    case "close-tab": {
      const tab = await allowedTab(args);
      await chrome.tabs.remove(tab.id);
      return { ok: true, message: `Closed tab id=${tab.id}.` };
    }
    case "navigate": {
      const tab = await targetTab(args);
      if (!(await connected(args.url || ""))) return { ok: false, message: NOT_CONNECTED(hostOf(args.url)) };
      await chrome.tabs.update(tab.id, { url: args.url });
      await waitForLoad(tab.id);
      return { ok: true, message: `Navigated to ${args.url}.` };
    }
    case "back": { const t = await allowedTab(args); await chrome.tabs.goBack(t.id); await waitForLoad(t.id); return { ok: true, message: "Went back." }; }
    case "forward": { const t = await allowedTab(args); await chrome.tabs.goForward(t.id); await waitForLoad(t.id); return { ok: true, message: "Went forward." }; }
    case "refresh": { const t = await allowedTab(args); await chrome.tabs.reload(t.id); await waitForLoad(t.id); return { ok: true, message: "Reloaded." }; }
    case "wait": {
      await new Promise((r) => setTimeout(r, Math.min(Number(args.ms) || 1000, 10000)));
      return { ok: true, message: "Waited." };
    }
    case "snapshot": return { ok: true, message: await run(await allowedTab(args), snapshotFn) };
    case "extract-text": return { ok: true, message: await run(await allowedTab(args), extractFn) };
    case "click": return pageResult(await run(await allowedTab(args), clickFn, [args.ref]));
    case "type": return pageResult(await run(await allowedTab(args), typeFn, [args.ref, args.text ?? "", args.append === "true"]));
    case "select": return pageResult(await run(await allowedTab(args), selectFn, [args.ref, args.value ?? ""]));
    case "scroll": return pageResult(await run(await allowedTab(args), scrollFn, [Number(args.dy) || 0, args.ref || null]));
    case "screenshot": {
      const tab = await allowedTab(args);
      await chrome.tabs.update(tab.id, { active: true });
      const dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId, { format: "png" });
      return { ok: true, message: "Screenshot taken.", image: dataUrl.split(",")[1] };
    }
    default:
      return { ok: false, message: `Unknown browser command ${cmd}.` };
  }
}

function hostOf(url) { try { return new URL(url).host; } catch { return "That address"; } }
function pageResult(r) { return r && r.error ? { ok: false, message: r.error } : { ok: true, message: (r && r.message) || "Done." }; }

function waitForLoad(tabId, timeout = 15000) {
  return new Promise((resolve) => {
    const done = () => { chrome.tabs.onUpdated.removeListener(listener); clearTimeout(timer); resolve(); };
    const listener = (id, info) => { if (id === tabId && info.status === "complete") done(); };
    const timer = setTimeout(done, timeout);
    chrome.tabs.onUpdated.addListener(listener);
    // Give a navigation a moment to start, then check whether it is already finished.
    setTimeout(async () => { try { if ((await chrome.tabs.get(tabId)).status === "complete") done(); } catch { done(); } }, 400);
  });
}

// ---------- Functions injected into the page (must be self-contained) ----------

function snapshotFn() {
  document.querySelectorAll("[data-haven-ref]").forEach((e) => e.removeAttribute("data-haven-ref"));
  const lines = [`Page: ${document.title} (${location.href})`];
  const selector = 'a[href],button,input,textarea,select,summary,[role=button],[role=link],[role=checkbox],[role=radio],[role=tab],[role=menuitem],[role=switch],[role=textbox],[role=combobox],[contenteditable=""],[contenteditable=true],h1,h2,h3';
  const visible = (el) => {
    const r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    const s = getComputedStyle(el);
    return s.visibility !== "hidden" && s.display !== "none" && parseFloat(s.opacity) > 0;
  };
  const clean = (t) => (t || "").trim().replace(/\s+/g, " ").slice(0, 80);
  const label = (el) =>
    clean(el.getAttribute("aria-label") || (el.labels && el.labels[0] && el.labels[0].innerText) || el.placeholder ||
      (["button", "submit", "reset"].includes(el.type) ? el.value : "") || el.innerText || el.title || el.alt || "");
  let n = 0;
  for (const el of document.querySelectorAll(selector)) {
    if (n >= 300) { lines.push("… (truncated)"); break; }
    if (!visible(el)) continue;
    const tag = el.tagName.toLowerCase();
    if (/^h[1-3]$/.test(tag)) { lines.push(`${tag} "${clean(el.innerText)}"`); continue; }
    n++;
    const ref = "b" + n;
    el.setAttribute("data-haven-ref", ref);
    const role = el.getAttribute("role") || (tag === "a" ? "link" : tag === "input" ? (el.type || "text") : tag);
    let extra = "";
    if (tag === "a") extra = ` href=${(el.getAttribute("href") || "").slice(0, 60)}`;
    if (tag === "input" || tag === "textarea" || tag === "select") {
      if (el.type === "password") extra = " (password field, not readable)";
      else if (el.type === "checkbox" || el.type === "radio") extra = el.checked ? " checked" : " unchecked";
      else if (el.value) extra = ` value="${String(el.value).slice(0, 40)}"`;
    }
    lines.push(`[${ref}] ${role} "${label(el)}"${extra}`);
  }
  return lines.join("\n");
}

function extractFn() {
  const text = (document.body && document.body.innerText || "").replace(/\n{3,}/g, "\n\n").trim();
  return `Page: ${document.title} (${location.href})\n\n` + (text.length > 20000 ? text.slice(0, 20000) + "\n… (truncated)" : text);
}

function findRef(ref) { return document.querySelector(`[data-haven-ref="${CSS.escape(String(ref))}"]`); }

function clickFn(ref) {
  const el = findRef(ref);
  if (!el) return { error: `Unknown reference ${ref}. Take a new snapshot first; references change each time.` };
  el.scrollIntoView({ block: "center" });
  el.click();
  return { message: `Clicked ${ref}.` };
}

function typeFn(ref, text, append) {
  const el = findRef(ref);
  if (!el) return { error: `Unknown reference ${ref}. Take a new snapshot first.` };
  if (el.type === "password" || /password/i.test(el.autocomplete || "")) {
    return { error: "Refusing to type into a password field. Use haven-vault login instead." };
  }
  el.scrollIntoView({ block: "center" });
  el.focus();
  if (el.isContentEditable) {
    if (!append) document.execCommand("selectAll", false);
    document.execCommand("insertText", false, text);
    return { message: `Typed ${text.length} characters into ${ref}.` };
  }
  const proto = el.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
  const setter = Object.getOwnPropertyDescriptor(proto, "value").set;
  setter.call(el, append ? (el.value || "") + text : text);
  el.dispatchEvent(new Event("input", { bubbles: true }));
  el.dispatchEvent(new Event("change", { bubbles: true }));
  return { message: `Typed ${text.length} characters into ${ref}.` };
}

function selectFn(ref, value) {
  const el = findRef(ref);
  if (!el || el.tagName !== "SELECT") return { error: `${ref} is not a dropdown. Take a new snapshot.` };
  const option = [...el.options].find((o) => o.value === value || o.text.trim() === value);
  if (!option) return { error: `No option "${value}". Options: ${[...el.options].map((o) => o.text.trim()).slice(0, 20).join(", ")}` };
  el.value = option.value;
  el.dispatchEvent(new Event("input", { bubbles: true }));
  el.dispatchEvent(new Event("change", { bubbles: true }));
  return { message: `Selected "${option.text.trim()}".` };
}

function scrollFn(dy, ref) {
  const target = ref ? findRef(ref) : null;
  if (ref && !target) return { error: `Unknown reference ${ref}.` };
  (target || window).scrollBy ? (target || window).scrollBy(0, -dy * 40) : window.scrollBy(0, -dy * 40);
  return { message: `Scrolled ${dy} lines.` };
}
