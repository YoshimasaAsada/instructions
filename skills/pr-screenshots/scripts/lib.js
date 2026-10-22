const fs = require('fs')
const path = require('path')

// dir とその2階層下までのディレクトリ（node_modules と隠しディレクトリは除く）
const candidateBases = (dir) => {
  const children = (d) => {
    try {
      return fs
        .readdirSync(d, { withFileTypes: true })
        .filter((e) => e.isDirectory() && e.name !== 'node_modules' && !e.name.startsWith('.'))
        .map((e) => path.join(d, e.name))
    } catch {
      return []
    }
  }
  const level1 = children(dir)
  return [dir, ...level1, ...level1.flatMap(children)]
}

// リポジトリの node_modules にある playwright を探す（PW 環境変数があればそれを使う）
const resolvePlaywright = () => {
  if (process.env.PW) return require(process.env.PW)
  try {
    return require('playwright')
  } catch {}
  let dir = process.cwd()
  while (dir !== path.dirname(dir)) {
    for (const base of candidateBases(dir)) {
      const pnpm = path.join(base, 'node_modules/.pnpm')
      if (!fs.existsSync(pnpm)) continue
      const found = fs
        .readdirSync(pnpm)
        .filter((n) => /^playwright@\d/.test(n))
        .sort()
        .map((n) => path.join(pnpm, n, 'node_modules/playwright'))
        .filter((p) => fs.existsSync(p))
      if (found.length) return require(found[0])
    }
    dir = path.dirname(dir)
  }
  throw new Error('playwright が見つからない。PW=<playwright のパス> を渡すこと')
}

module.exports = { resolvePlaywright }
