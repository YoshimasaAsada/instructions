// capture.js の出力を、PR に貼る1枚の画像にまとめる
// usage: node compose.js <spec.json>
// spec: { out, title, note, dir, keys: ["about"], before?: true,
//         beforeLabel?, afterLabel?, viewports?: ["pc", "sp"], viewportLabels?: { pc?: "PC（約1350px）" } }
// viewportLabels: 実際に撮った幅が既定（PC 1366px / SP 375px）と違うときに見出しを差し替える
// before: true なら PC・SP ごとに変更前／変更後を左右に並べる。false なら変更後の PC と SP を並べる
const fs = require('fs')
const path = require('path')
const { resolvePlaywright } = require('./lib')

const spec = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
const {
  out,
  title,
  note,
  dir,
  keys,
  before = false,
  beforeLabel = '変更前',
  afterLabel = '変更後',
  viewports = ['pc', 'sp'],
  viewportLabels = {},
} = spec

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c])
const VP = { pc: { label: 'PC（1366px）', width: 900 }, sp: { label: 'SP（375px）', width: 375 } }
const vpLabel = (v) => viewportLabels[v] || VP[v].label
// 新規のブロックは変更前の画像が無いので、その位置に「新規」の札を出して変更後と並びをそろえる
const frame = (f, width) =>
  fs.existsSync(path.resolve(dir, `${f}.png`))
    ? `<div class="frame"><img src="file://${path.resolve(dir, f)}.png" width="${width}"></div>`
    : `<div class="frame none" style="width:${width}px">新規（変更前なし）</div>`
const col = (label, files, width) =>
  `<div class="col"><p>${esc(label)}</p><div class="stack">${files.map((f) => frame(f, width)).join('')}</div></div>`

let body = ''
if (before) {
  for (const v of viewports) {
    body += `<h2>${esc(vpLabel(v))}</h2><div class="row">${col(
      beforeLabel,
      keys.map((k) => `before-${v}-${k}`),
      VP[v].width
    )}${col(afterLabel, keys.map((k) => `after-${v}-${k}`), VP[v].width)}</div>`
  }
} else {
  body = `<div class="row">${viewports
    .map((v) => col(vpLabel(v), keys.map((k) => `after-${v}-${k}`), VP[v].width))
    .join('')}</div>`
}

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;padding:24px;background:#f4f4f5;font-family:-apple-system,"Hiragino Sans",sans-serif;color:#18181b}
h1{font-size:26px;margin:0 0 4px}.sub{font-size:15px;color:#52525b;margin:0 0 20px}
h2{font-size:20px;margin:16px 0 10px}.row{display:flex;gap:24px;align-items:flex-start;margin-bottom:24px}
.col p{font-size:16px;font-weight:700;margin:0 0 8px}.stack{display:flex;flex-direction:column;gap:12px}
.frame{border:1px solid #d4d4d8;background:#fff}.frame img{display:block}
.none{display:flex;align-items:center;justify-content:center;height:120px;color:#71717a;font-size:16px;font-weight:700;background:#fafafa;border-style:dashed}
</style></head><body><h1>${esc(title)}</h1><p class="sub">${esc(note)}</p>${body}</body></html>`

;(async () => {
  const htmlPath = `${out}.html`
  fs.writeFileSync(htmlPath, html)
  const { chromium } = resolvePlaywright()
  const browser = await chromium.launch()
  const page = await browser.newPage({ viewport: { width: 1900, height: 1000 }, deviceScaleFactor: 1 })
  await page.goto(`file://${path.resolve(htmlPath)}`)
  await page.waitForTimeout(500)
  await page.screenshot({ path: out, fullPage: true })
  await browser.close()
  fs.unlinkSync(htmlPath)
  console.log('->', out)
})()
