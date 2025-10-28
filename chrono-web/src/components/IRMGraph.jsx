import { useRef, useEffect, useState } from 'react'

export default function IRMGraph({ currentUtilization }) {
  const svgRef = useRef()
  const [hoverData, setHoverData] = useState(null)

  // IRM Parameters (Kink model) - google se mila stats
  const kinkUtilization = 90 // 90% utilization
  const baseRate = 0 // 0% APY at 0 utilization
  const slope1 = 0.05 // 5% increase per 100% utilization before kink
  const slope2 = 0.5 // 50% increase per 100% utilization after kink

  const calculateAPY = (utilization) => {
    if (utilization <= kinkUtilization) {
      return baseRate + (slope1 * utilization)
    } else {
      // After kinksteep slope
      const kinkAPY = baseRate + (slope1 * kinkUtilization)
      return kinkAPY + (slope2 * (utilization - kinkUtilization))
    }
  }

  useEffect(() => {
    const svg = svgRef.current
    const width = svg.clientWidth
    const height = svg.clientHeight
    const margin = { top: 20, right: 30, bottom: 50, left: 60 }
    const innerWidth = width - margin.left - margin.right
    const innerHeight = height - margin.top - margin.bottom

    while (svg.firstChild) {
      svg.removeChild(svg.firstChild)
    }

    const g = document.createElementNS("http://www.w3.org/2000/svg", "g")
    g.setAttribute("transform", `translate(${margin.left},${margin.top})`)
    svg.appendChild(g)

    const data = []
    for (let i = 0; i <= 100; i += 0.5) {
      data.push({ utilization: i, apy: calculateAPY(i) })
    }

    const maxAPY = calculateAPY(100)

    const xScale = (utilization) => (utilization / 100) * innerWidth
    const yScale = (apy) => innerHeight - ((apy / maxAPY) * innerHeight)

    for (let i = 0; i <= 5; i++) {
      const util = i * 20
      const x = xScale(util)
      
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
      line.setAttribute("x1", x)
      line.setAttribute("y1", 0)
      line.setAttribute("x2", x)
      line.setAttribute("y2", innerHeight)
      line.setAttribute("stroke", "#333")
      line.setAttribute("stroke-dasharray", "2,2")
      g.appendChild(line)

      const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
      text.setAttribute("x", x)
      text.setAttribute("y", innerHeight + 20)
      text.setAttribute("text-anchor", "middle")
      text.setAttribute("fill", "#a0a0a0")
      text.setAttribute("font-size", "12px")
      text.textContent = `${util}%`
      g.appendChild(text)
    }

    const xLabel = document.createElementNS("http://www.w3.org/2000/svg", "text")
    xLabel.setAttribute("x", innerWidth / 2)
    xLabel.setAttribute("y", innerHeight + 40)
    xLabel.setAttribute("text-anchor", "middle")
    xLabel.setAttribute("fill", "#a0a0a0")
    xLabel.setAttribute("font-size", "12px")
    xLabel.setAttribute("font-weight", "600")
    xLabel.textContent = "Utilization"
    g.appendChild(xLabel)

    const numYTicks = 6
    for (let i = 0; i <= numYTicks; i++) {
      const apy = (i / numYTicks) * maxAPY
      const y = yScale(apy)
      
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
      line.setAttribute("x1", 0)
      line.setAttribute("y1", y)
      line.setAttribute("x2", innerWidth)
      line.setAttribute("y2", y)
      line.setAttribute("stroke", "#333")
      line.setAttribute("stroke-dasharray", "2,2")
      g.appendChild(line)

      const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
      text.setAttribute("x", -10)
      text.setAttribute("y", y + 4)
      text.setAttribute("text-anchor", "end")
      text.setAttribute("fill", "#a0a0a0")
      text.setAttribute("font-size", "12px")
      text.textContent = `${apy.toFixed(0)}%`
      g.appendChild(text)
    }

    const yLabel = document.createElementNS("http://www.w3.org/2000/svg", "text")
    yLabel.setAttribute("x", -innerHeight / 2)
    yLabel.setAttribute("y", -45)
    yLabel.setAttribute("text-anchor", "middle")
    yLabel.setAttribute("fill", "#a0a0a0")
    yLabel.setAttribute("font-size", "12px")
    yLabel.setAttribute("font-weight", "600")
    yLabel.setAttribute("transform", `rotate(-90, ${-innerHeight / 2}, -45)`)
    yLabel.textContent = "APY"
    g.appendChild(yLabel)

    const borrowPath = document.createElementNS("http://www.w3.org/2000/svg", "path")
    borrowPath.setAttribute("fill", "none")
    borrowPath.setAttribute("stroke", "orange")
    borrowPath.setAttribute("stroke-width", "3")
    const borrowPathData = data.map((d, i) => {
      return `${i === 0 ? 'M' : 'L'}${xScale(d.utilization)},${yScale(d.apy)}`
    }).join(' ')
    borrowPath.setAttribute("d", borrowPathData)
    g.appendChild(borrowPath)

    const supplyPath = document.createElementNS("http://www.w3.org/2000/svg", "path")
    supplyPath.setAttribute("fill", "none")
    supplyPath.setAttribute("stroke", "#c5ff4a")
    supplyPath.setAttribute("stroke-width", "3")
    const supplyPathData = data.map((d, i) => {
      const supplyAPY = d.apy * (d.utilization / 100)
      return `${i === 0 ? 'M' : 'L'}${xScale(d.utilization)},${yScale(supplyAPY)}`
    }).join(' ')
    supplyPath.setAttribute("d", supplyPathData)
    g.appendChild(supplyPath)

    const kinkX = xScale(kinkUtilization)
    const kinkY = yScale(calculateAPY(kinkUtilization))

    const kinkLine = document.createElementNS("http://www.w3.org/2000/svg", "line")
    kinkLine.setAttribute("x1", kinkX)
    kinkLine.setAttribute("y1", 0)
    kinkLine.setAttribute("x2", kinkX)
    kinkLine.setAttribute("y2", innerHeight)
    kinkLine.setAttribute("stroke", "#c5ff4a")
    kinkLine.setAttribute("stroke-width", "1")
    kinkLine.setAttribute("stroke-dasharray", "4,4")
    g.appendChild(kinkLine)

    const kinkCircle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    kinkCircle.setAttribute("cx", kinkX)
    kinkCircle.setAttribute("cy", kinkY)
    kinkCircle.setAttribute("r", "5")
    kinkCircle.setAttribute("fill", "#c5ff4a")
    kinkCircle.setAttribute("stroke", "white")
    kinkCircle.setAttribute("stroke-width", "2")
    g.appendChild(kinkCircle)

    
    const kinkLabel = document.createElementNS("http://www.w3.org/2000/svg", "text")
    kinkLabel.setAttribute("x", kinkX)
    kinkLabel.setAttribute("y", kinkY - 15)
    kinkLabel.setAttribute("text-anchor", "middle")
    kinkLabel.setAttribute("fill", "#c5ff4a")
    kinkLabel.setAttribute("font-size", "12px")
    kinkLabel.setAttribute("font-weight", "bold")
    kinkLabel.textContent = `Kink (${kinkUtilization}%)`
    g.appendChild(kinkLabel)

    if (currentUtilization > 0) {
      const currentX = xScale(currentUtilization)
      const currentAPY = calculateAPY(currentUtilization)
      const currentY = yScale(currentAPY)

      const currentLine = document.createElementNS("http://www.w3.org/2000/svg", "line")
      currentLine.setAttribute("x1", currentX)
      currentLine.setAttribute("y1", 0)
      currentLine.setAttribute("x2", currentX)
      currentLine.setAttribute("y2", innerHeight)
      currentLine.setAttribute("stroke", "orange")
      currentLine.setAttribute("stroke-width", "2")
      currentLine.setAttribute("stroke-dasharray", "4,4")
      g.appendChild(currentLine)

      const currentCircle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      currentCircle.setAttribute("cx", currentX)
      currentCircle.setAttribute("cy", currentY)
      currentCircle.setAttribute("r", "5")
      currentCircle.setAttribute("fill", "orange")
      currentCircle.setAttribute("stroke", "white")
      currentCircle.setAttribute("stroke-width", "2")
      g.appendChild(currentCircle)

      const currentLabel = document.createElementNS("http://www.w3.org/2000/svg", "text")
      currentLabel.setAttribute("x", currentX)
      currentLabel.setAttribute("y", currentY + 25)
      currentLabel.setAttribute("text-anchor", "middle")
      currentLabel.setAttribute("fill", "orange")
      currentLabel.setAttribute("font-size", "12px")
      currentLabel.setAttribute("font-weight", "bold")
      currentLabel.textContent = `Current (${currentUtilization.toFixed(2)}%)`
      g.appendChild(currentLabel)
    }

    const overlay = document.createElementNS("http://www.w3.org/2000/svg", "rect")
    overlay.setAttribute("width", innerWidth)
    overlay.setAttribute("height", innerHeight)
    overlay.setAttribute("fill", "transparent")
    g.appendChild(overlay)

    const hoverLineX = document.createElementNS("http://www.w3.org/2000/svg", "line")
    hoverLineX.setAttribute("stroke", "#a0a0a0")
    hoverLineX.setAttribute("stroke-width", "1")
    hoverLineX.setAttribute("stroke-dasharray", "2,2")
    hoverLineX.style.opacity = 0
    g.appendChild(hoverLineX)

    const hoverLineY = document.createElementNS("http://www.w3.org/2000/svg", "line")
    hoverLineY.setAttribute("stroke", "#a0a0a0")
    hoverLineY.setAttribute("stroke-width", "1")
    hoverLineY.setAttribute("stroke-dasharray", "2,2")
    hoverLineY.style.opacity = 0
    g.appendChild(hoverLineY)

    const hoverCircleBorrow = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    hoverCircleBorrow.setAttribute("r", "4")
    hoverCircleBorrow.setAttribute("fill", "orange")
    hoverCircleBorrow.setAttribute("stroke", "white")
    hoverCircleBorrow.setAttribute("stroke-width", "1.5")
    hoverCircleBorrow.style.opacity = 0
    g.appendChild(hoverCircleBorrow)

    const hoverCircleSupply = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    hoverCircleSupply.setAttribute("r", "4")
    hoverCircleSupply.setAttribute("fill", "#c5ff4a")
    hoverCircleSupply.setAttribute("stroke", "white")
    hoverCircleSupply.setAttribute("stroke-width", "1.5")
    hoverCircleSupply.style.opacity = 0
    g.appendChild(hoverCircleSupply)

    overlay.onmousemove = (event) => {
      const rect = overlay.getBoundingClientRect()
      const svgRect = svg.getBoundingClientRect()
      const mouseX = event.clientX - rect.left
      const mouseY = event.clientY - rect.top

      const hoveredUtil = (mouseX / innerWidth) * 100
      const hoveredBorrowAPY = calculateAPY(hoveredUtil)
      const hoveredSupplyAPY = hoveredBorrowAPY * (hoveredUtil / 100)

      hoverLineX.setAttribute("x1", mouseX)
      hoverLineX.setAttribute("y1", 0)
      hoverLineX.setAttribute("x2", mouseX)
      hoverLineX.setAttribute("y2", innerHeight)
      hoverLineX.style.opacity = 1

      hoverLineY.setAttribute("x1", 0)
      hoverLineY.setAttribute("y1", mouseY)
      hoverLineY.setAttribute("x2", innerWidth)
      hoverLineY.setAttribute("y2", mouseY)
      hoverLineY.style.opacity = 1

      hoverCircleBorrow.setAttribute("cx", mouseX)
      hoverCircleBorrow.setAttribute("cy", yScale(hoveredBorrowAPY))
      hoverCircleBorrow.style.opacity = 1

      hoverCircleSupply.setAttribute("cx", mouseX)
      hoverCircleSupply.setAttribute("cy", yScale(hoveredSupplyAPY))
      hoverCircleSupply.style.opacity = 1

      const tooltipX = event.clientX - svgRect.left
      const tooltipY = event.clientY - svgRect.top
      
      setHoverData({
        utilization: hoveredUtil.toFixed(1),
        borrowAPY: hoveredBorrowAPY.toFixed(2),
        supplyAPY: hoveredSupplyAPY.toFixed(2),
        x: tooltipX,
        y: tooltipY
      })
    }

    overlay.onmouseleave = () => {
      hoverLineX.style.opacity = 0
      hoverLineY.style.opacity = 0
      hoverCircleBorrow.style.opacity = 0
      hoverCircleSupply.style.opacity = 0
      setHoverData(null)
    }
    //eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentUtilization])

  return (
    <div className="relative w-full h-80">
      <svg ref={svgRef} className="w-full h-full"></svg>
      
      {hoverData && (
        <div
          className="absolute pointer-events-none bg-neutral-800/95 border border-neutral-700 rounded-lg p-3 shadow-lg z-10"
          style={{ 
            left: `${hoverData.x + 15}px`,
            top: `${hoverData.y - 80}px`
          }}
        >
          <div className="text-xs space-y-1.5">
            <div className="flex items-center gap-2">
              <span className="text-gray-400">Utilization:</span>
              <span className="text-white font-semibold">{hoverData.utilization}%</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-orange-500"></div>
              <span className="text-gray-400">Borrow APY:</span>
              <span className="text-white font-semibold">{hoverData.borrowAPY}%</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-[#c5ff4a]"></div>
              <span className="text-gray-400">Supply APY:</span>
              <span className="text-white font-semibold">{hoverData.supplyAPY}%</span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

