// 対象のブロックを赤枠で囲み、前後が少し見える範囲で切り出す
// usage: node capture.js <config.json>
// 出力: <outDir>/<label>-<viewport>-<key>.png
const fs = require('fs')
const { resolvePlaywright } = require('./lib')

const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
const {
  url,
  label,
  outDir,
  targets,
  container,
  viewports = ['pc', 'sp'],
  margin = 48,
  hideSelectors = ['nextjs-portal'],
  waitMs = 1500,
} = config

const VIEWPORTS = {
  pc: { width: 1366, height: 900, isMobile: false },
  sp: { width: 375, height: 812, isMobile: true },
}

const locate = ({ targets, container }) => {
  const visible = (e) => {
    const r = e.getBoundingClientRect()
    return r.width > 0 && r.height > 0
  }
  const byText = (root, text) =>
    [...root.querySelectorAll('*')].filter(
      (e) =>
        e.textContent.trim() === text &&
        visible(e) &&
        ![...e.children].some((c) => c.textContent.trim() === text)
    )[0]
  // 各ブロックを並べている親要素。目印の文言2つの共通の祖先か、CSS セレクタで決める
  let c = null
  if (container?.selector) c = document.querySelector(container.selector)
  if (container?.markers) {
    const [a, b] = container.markers.map((t) => byText(document, t))
    if (!a || !b) return { error: `container marker not found: ${container.markers}` }
    c = a.parentElement
    while (!c.contains(b)) c = c.parentElement
  }
  const sectionOf = (el) => {
    if (!c) return el
    let s = el
    while (s && s.parentElement !== c) s = s.parentElement
    return s
  }
  const res = {}
  for (const t of targets) {
    let el = null
    if (t.index !== undefined) el = c?.children[t.index]
    else if (t.selector) el = document.querySelector(t.selector)
    else if (t.text) el = byText(c || document, t.text)
    if (el && !t.exact) el = sectionOf(el)
    if (!el) {
      res[t.key] = null
      continue
    }
    const r = el.getBoundingClientRect()
    res[t.key] = { x: r.x + window.scrollX, y: r.y + window.scrollY, width: r.width, height: r.height }
  }
  return res
}

;(async () => {
  const { chromium } = resolvePlaywright()
  fs.mkdirSync(outDir, { recursive: true })
  const browser = await chromium.launch()
  for (const name of viewports) {
    const vp = VIEWPORTS[name]
    const ctx = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      deviceScaleFactor: 2,
      isMobile: vp.isMobile,
      hasTouch: vp.isMobile,
    })
    const page = await ctx.newPage()
    await page.goto(url, { waitUntil: 'networkidle', timeout: 180000 })
    if (hideSelectors.length) await page.addStyleTag({ content: `${hideSelectors.join(',')}{display:none!important}` })
    // 遅延読み込みの画像を出し切る
    await page.evaluate(async () => {
      for (let y = 0; y < document.body.scrollHeight; y += 400) {
        window.scrollTo(0, y)
        await new Promise((r) => setTimeout(r, 120))
      }
      window.scrollTo(0, 0)
    })
    await page.waitForLoadState('networkidle')
    await page.waitForTimeout(waitMs)
    const rects = await page.evaluate(locate, { targets, container })
    if (rects.error) {
      console.log(name, rects.error)
      await ctx.close()
      continue
    }
    for (const [key, r] of Object.entries(rects)) {
      if (!r) {
        console.log(name, key, 'not found')
        continue
      }
      // 枠の線で中身を隠さないよう、上下はブロックの外側に描く
      await page.evaluate((r) => {
        const d = document.createElement('div')
        d.id = '__pr_shot_box'
        Object.assign(d.style, {
          position: 'absolute',
          left: `${r.x + 3}px`,
          top: `${r.y - 10}px`,
          width: `${r.width - 6}px`,
          height: `${r.height + 20}px`,
          border: '6px solid #e11d48',
          borderRadius: '6px',
          boxSizing: 'border-box',
          zIndex: 2147483647,
          pointerEvents: 'none',
        })
        document.body.appendChild(d)
      }, r)
      const y0 = Math.max(0, r.y - margin)
      const file = `${outDir}/${label}-${name}-${key}.png`
      await page.screenshot({
        path: file,
        fullPage: true,
        clip: { x: 0, y: y0, width: vp.width, height: r.height + (r.y - y0) + margin },
      })
      await page.evaluate(() => document.getElementById('__pr_shot_box').remove())
      console.log(name, key, '->', file)
    }
    await ctx.close()
  }
  await browser.close()
})()
