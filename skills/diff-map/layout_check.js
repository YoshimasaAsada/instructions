// 差分の地図の目視を補う機械チェック。ブラウザで地図を開いた状態で javascript_exec に丸ごと渡す。
// SVG の座標は viewBox 基準なので、ノード内の文字のはみ出しと文字同士の重なりは表示幅に関係なく判定できる。
// 実表示の文字サイズとページの横はみ出しは、そのときの表示幅での値になる（狭い幅とデスクトップ幅の両方で流す）。
(() => {
  const issues = []
  const intersects = (a, b) =>
    !(a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y)

  document.querySelectorAll('figure svg').forEach((svg, index) => {
    const name = `図${index + 1}`
    svg.querySelectorAll('g.node').forEach((node) => {
      const box = node.querySelector('rect').getBBox()
      node.querySelectorAll('text').forEach((text) => {
        const b = text.getBBox()
        if (b.x < box.x + 2 || b.x + b.width > box.x + box.width - 2) {
          issues.push(`${name} ノードからはみ出し: ${text.textContent}（文字 ${Math.round(b.width)} / ノード ${box.width}）`)
        }
      })
    })

    const texts = [...svg.querySelectorAll('text')].map((text) => ({ label: text.textContent, box: text.getBBox() }))
    texts.forEach((a, i) =>
      texts.slice(i + 1).forEach((b) => {
        if (intersects(a.box, b.box)) issues.push(`${name} 文字の重なり: ${a.label} × ${b.label}`)
      })
    )

    svg.querySelectorAll('text.t-edge').forEach((text) => {
      const b = text.getBBox()
      svg.querySelectorAll('g.node rect').forEach((rect) => {
        if (intersects(b, rect.getBBox())) issues.push(`${name} エッジラベルがノードに重なる: ${text.textContent}`)
      })
    })

    const scale = svg.getBoundingClientRect().width / svg.viewBox.baseVal.width
    const minFont = Math.min(...[...svg.querySelectorAll('text')].map((t) => parseFloat(getComputedStyle(t).fontSize) * scale))
    if (minFont < 12) issues.push(`${name} 実表示の最小文字 ${minFont.toFixed(1)}px（12px 未満）`)
  })

  const root = document.documentElement
  if (root.scrollWidth > root.clientWidth) {
    const offenders = [...document.querySelectorAll('main *')]
      .filter((el) => el.getBoundingClientRect().right > root.clientWidth + 1 && !el.closest('.figscroll, .table-wrap, pre, .screen'))
      .slice(0, 5)
      .map((el) => `${el.tagName.toLowerCase()} 「${(el.textContent || '').trim().slice(0, 30)}」`)
    issues.push(`ページが横にはみ出している（幅 ${root.clientWidth}px）: ${offenders.join(' / ')}`)
  }

  return { width: root.clientWidth, ok: issues.length === 0, issues }
})()
