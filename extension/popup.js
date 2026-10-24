// Lets the person connect or disconnect the current site. Chrome shows its own permission prompt.
const $ = (id) => document.getElementById(id);

async function currentOrigin() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  try {
    const u = new URL(tab.url);
    return /^https?:$/.test(u.protocol) ? u.origin : null;
  } catch { return null; }
}

async function render() {
  const { status } = await chrome.storage.session.get("status");
  $("status").textContent = status || "Starting…";

  const origin = await currentOrigin();
  const pattern = origin && `${origin}/*`;
  const granted = origin ? await chrome.permissions.contains({ origins: [pattern] }) : false;

  $("site").textContent = origin ? new URL(origin).host : "This page";
  $("hint").textContent = !origin
    ? "Haven can only work on regular web pages."
    : granted
      ? "Haven's agents can read and act on this site while you run a task. Disconnect any time."
      : "Haven's agents cannot see or act on this site until you connect it.";
  const toggle = $("toggle");
  toggle.style.display = origin ? "block" : "none";
  toggle.textContent = granted ? "Disconnect this site" : "Connect this site";
  toggle.className = granted ? "secondary" : "";
  toggle.onclick = async () => {
    if (granted) await chrome.permissions.remove({ origins: [pattern] });
    else await chrome.permissions.request({ origins: [pattern] });
    render();
  };

  const origins = (await chrome.permissions.getAll()).origins || [];
  const list = $("sites");
  list.innerHTML = "";
  if (!origins.length) { const li = document.createElement("li"); li.textContent = "None yet"; list.append(li); }
  for (const o of origins) {
    const li = document.createElement("li");
    const name = document.createElement("span");
    name.textContent = o.replace(/\/\*$/, "").replace(/^https?:\/\//, "");
    const btn = document.createElement("button");
    btn.className = "secondary";
    btn.textContent = "Remove";
    btn.onclick = async () => { await chrome.permissions.remove({ origins: [o] }); render(); };
    li.append(name, btn);
    list.append(li);
  }
}
render();
