# Haven browser extension

Lets Haven's agents read and act on web pages in your own browser, only on sites you connect.

## Install (development)

1. In Haven, open **Settings > Browser** and choose **Show Folder** to reveal this folder.
2. In Chrome (or Brave, Edge, Arc): open `chrome://extensions`, turn on **Developer mode**, choose **Load unpacked**, and pick this folder.
3. Open the extension's **options** and paste the pairing code from Haven.
4. On a site you want agents to use, click the Haven icon and choose **Connect this site**. Chrome shows its own permission prompt.

The extension has a fixed ID (set by the public key in `manifest.json`), which Haven checks when the extension connects.

## How it works

- The extension connects to the Haven app at `ws://127.0.0.1:48731`. Haven listens on the loopback address only.
- The first message must carry the pairing code. A web page cannot connect, because it does not know the code and its `Origin` is not the extension's.
- Chrome enforces "only sites you connect": commands run only on origins you granted from the popup. `list-tabs` shows titles only for connected sites.
- Page commands: `snapshot` (outline with `[bN]` references), `extract-text`, `click`, `type`, `select`, `scroll`, plus tab navigation. Password fields are never read and never typed into; logins go through Haven's vault.
- Limits: top-level frames only (no iframes or closed shadow roots), no screenshots yet (Chrome only allows them with all-sites access, which would defeat per-site consent).

## Notes for developers

- Chrome 137 and later ignore `--load-extension`; load the folder from `chrome://extensions` instead.
- `HAVEN_BROWSER_SCRIPT=file` runs a list of bridge commands (one per line, options joined with ` && `) against a connected extension and writes `file.out`; useful for testing without an agent.
