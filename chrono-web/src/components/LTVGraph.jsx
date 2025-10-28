import { useEffect, useRef, useState } from 'react'

export default function LTVGraph({ currentTime }) {
  const svgRef = useRef()
  const [hoverPoint, setHoverPoint] = useState(null)

  useEffect(() => {
    drawGraph()
    ////eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentTime])

  const calculateLTV = (t) => {
    return 75 + 15 * Math.exp(-0.000333 * t)
  }

  const drawGraph = () => {
    const svg = svgRef.current
    if (!svg) return

    while (svg.firstChild) {
      svg.removeChild(svg.firstChild)
    }

    const width = 500
    const height = 300
    const padding = 50

    svg.setAttribute('viewBox', `0 0 ${width} ${height}`)
    svg.setAttribute('class', 'w-full h-64')

    const bg = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
    bg.setAttribute('width', width)
    bg.setAttribute('height', height)
    bg.setAttribute('fill', '#171717')
    svg.appendChild(bg)

    const minY = 75
    const maxY = 90
    const ySteps = 6
    for (let i = 0; i <= ySteps; i++) {
      const yValue = minY + (maxY - minY) * i / ySteps
      const y = height - padding - ((yValue - minY) / (maxY - minY)) * (height - 2 * padding)
      
      const line = document.createElementNS('http://www.w3.org/2000/svg', 'line')
      line.setAttribute('x1', padding)
      line.setAttribute('y1', y)
      line.setAttribute('x2', width - padding)
      line.setAttribute('y2', y)
      line.setAttribute('stroke', '#262626')
      line.setAttribute('stroke-width', '1')
      svg.appendChild(line)

      const label = document.createElementNS('http://www.w3.org/2000/svg', 'text')
      label.setAttribute('x', padding - 10)
      label.setAttribute('y', y + 4)
      label.setAttribute('fill', '#9ca3af')
      label.setAttribute('font-size', '10')
      label.setAttribute('text-anchor', 'end')
      label.textContent = yValue.toFixed(1) + '%'
      svg.appendChild(label)
    }

    const maxTime = 10000
    const xSteps = 5
    for (let i = 0; i <= xSteps; i++) {
      const xValue = (maxTime / xSteps) * i
      const x = padding + (width - 2 * padding) * (xValue / maxTime)
      
      const label = document.createElementNS('http://www.w3.org/2000/svg', 'text')
      label.setAttribute('x', x)
      label.setAttribute('y', height - padding + 20)
      label.setAttribute('fill', '#9ca3af')
      label.setAttribute('font-size', '10')
      label.setAttribute('text-anchor', 'middle')
      label.textContent = xValue.toFixed(0)
      svg.appendChild(label)
    }

    const dataPoints = []
    for (let t = 0; t <= maxTime; t += 100) {
      const ltv = calculateLTV(t)
      const x = padding + (width - 2 * padding) * (t / maxTime)
      const y = height - padding - ((ltv - minY) / (maxY - minY)) * (height - 2 * padding)
      dataPoints.push({ x, y, t, ltv })
    }

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    let d = `M ${dataPoints[0].x} ${dataPoints[0].y}`
    for (let i = 1; i < dataPoints.length; i++) {
      d += ` L ${dataPoints[i].x} ${dataPoints[i].y}`
    }
    path.setAttribute('d', d)
    path.setAttribute('stroke', '#c5ff4a')
    path.setAttribute('stroke-width', '2')
    path.setAttribute('fill', 'none')
    svg.appendChild(path)

    if (currentTime > 0) {
      const currentLTV = calculateLTV(currentTime)
      const markerX = padding + (width - 2 * padding) * (Math.min(currentTime, maxTime) / maxTime)
      const markerY = height - padding - ((currentLTV - minY) / (maxY - minY)) * (height - 2 * padding)

      const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle')
      circle.setAttribute('cx', markerX)
      circle.setAttribute('cy', markerY)
      circle.setAttribute('r', '5')
      circle.setAttribute('fill', '#c5ff4a')
      svg.appendChild(circle)

      const text = document.createElementNS('http://www.w3.org/2000/svg', 'text')
      text.setAttribute('x', markerX)
      text.setAttribute('y', markerY - 12)
      text.setAttribute('fill', '#fff')
      text.setAttribute('font-size', '11')
      text.setAttribute('font-weight', 'bold')
      text.setAttribute('text-anchor', 'middle')
      text.textContent = `${currentLTV.toFixed(2)}%`
      svg.appendChild(text)
    }

    const hoverRect = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
    hoverRect.setAttribute('x', padding)
    hoverRect.setAttribute('y', padding)
    hoverRect.setAttribute('width', width - 2 * padding)
    hoverRect.setAttribute('height', height - 2 * padding)
    hoverRect.setAttribute('fill', 'transparent')
    hoverRect.style.cursor = 'crosshair'
    
    hoverRect.addEventListener('mousemove', (e) => {
      const rect = svg.getBoundingClientRect()
      const mouseX = e.clientX - rect.left
      const mouseY = e.clientY - rect.top
      
      const svgX = (mouseX / rect.width) * width
      const svgY = (mouseY / rect.height) * height
      
      if (svgX >= padding && svgX <= width - padding && svgY >= padding && svgY <= height - padding) {
        const t = ((svgX - padding) / (width - 2 * padding)) * maxTime
        const ltv = calculateLTV(t)
        setHoverPoint({ t: t.toFixed(0), ltv: ltv.toFixed(2), x: svgX, y: svgY })
      }
    })
    
    hoverRect.addEventListener('mouseleave', () => {
      setHoverPoint(null)
    })
    
    svg.appendChild(hoverRect)

    const xLabel = document.createElementNS('http://www.w3.org/2000/svg', 'text')
    xLabel.setAttribute('x', width / 2)
    xLabel.setAttribute('y', height - 5)
    xLabel.setAttribute('fill', '#9ca3af')
    xLabel.setAttribute('font-size', '11')
    xLabel.setAttribute('text-anchor', 'middle')
    xLabel.textContent = 'Time (minutes)'
    svg.appendChild(xLabel)

    const yLabel = document.createElementNS('http://www.w3.org/2000/svg', 'text')
    yLabel.setAttribute('x', 12)
    yLabel.setAttribute('y', height / 2)
    yLabel.setAttribute('fill', '#9ca3af')
    yLabel.setAttribute('font-size', '11')
    yLabel.setAttribute('text-anchor', 'middle')
    yLabel.setAttribute('transform', `rotate(-90, 12, ${height / 2})`)
    yLabel.textContent = 'LTV (%)'
    svg.appendChild(yLabel)
  }

  return (
    <div className="relative">
      <svg ref={svgRef}></svg>
      {hoverPoint && (
        <div 
          className="absolute bg-neutral-800 border border-neutral-700 rounded px-2 py-1 text-xs text-white pointer-events-none z-10"
          style={{ 
            left: `${(hoverPoint.x / 500) * 100}%`, 
            top: `${(hoverPoint.y / 300) * 100 - 10}%`,
            transform: 'translate(-50%, -100%)'
          }}
        >
          <div>Time: {hoverPoint.t} min</div>
          <div className="text-[#c5ff4a]">LTV: {hoverPoint.ltv}%</div>
        </div>
      )}
      <div className="mt-2 text-xs text-gray-500 text-center">
        Formula: LTV = 75 + 15 × e^(-0.000333t)
      </div>
    </div>
  )
}
