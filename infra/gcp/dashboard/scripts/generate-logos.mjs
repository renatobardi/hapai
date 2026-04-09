#!/usr/bin/env node
import sharp from 'sharp'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const publicDir = path.join(__dirname, '../public')

// Ensure public directory exists
if (!fs.existsSync(publicDir)) {
  fs.mkdirSync(publicDir, { recursive: true })
}

// Logo dimensions (lg variant, scaled 2x for better resolution)
const SCALE = 2
const dashHeight = 5 * SCALE // 10px
const dashWidths = [30 * SCALE, 50 * SCALE, 40 * SCALE] // [60px, 100px, 80px]
const dashGap = 4 * SCALE // 8px
const barWidth = 5 * SCALE // 10px
const barHeight = 80 * SCALE // 160px
const barMargin = 10 * SCALE // 20px
const textSize = 56 * SCALE // 112px
const padding = 20 * SCALE // 20px

// Calculate dimensions
const dashColumnWidth = Math.max(...dashWidths)
const dashColumnHeight = (dashHeight * 3) + (dashGap * 2)
const svgWidth = padding + dashColumnWidth + barMargin + barWidth + barMargin + 320 + padding
const svgHeight = padding + Math.max(dashColumnHeight, barHeight) + padding

function generateSVG(lightMode = true) {
  const dashColor = lightMode ? '#ffffff' : '#1a1a1a'
  const textColor = lightMode ? '#ffffff' : '#1a1a1a'
  const barColor = '#06e0f9'

  // Calculate vertical centering for dashes
  const containerHeight = barHeight
  const dashYOffset = (containerHeight - dashColumnHeight) / 2

  let svg = `<svg width="${svgWidth}" height="${svgHeight}" viewBox="0 0 ${svgWidth} ${svgHeight}" xmlns="http://www.w3.org/2000/svg">`
  svg += `<defs><style>text { font-family: 'Space Grotesk', system-ui, sans-serif; font-weight: 700; }</style></defs>`

  // Background (transparent, no need to draw)

  // Draw dashes
  let y = padding + dashYOffset
  for (let i = 0; i < dashWidths.length; i++) {
    svg += `<rect x="${padding}" y="${y}" width="${dashWidths[i]}" height="${dashHeight}" fill="${dashColor}" />`
    y += dashHeight + dashGap
  }

  // Draw vertical bar
  const barX = padding + dashColumnWidth + barMargin
  const barY = padding + (containerHeight - barHeight) / 2
  svg += `<rect x="${barX}" y="${barY}" width="${barWidth}" height="${barHeight}" fill="${barColor}" />`

  // Draw text
  const textX = barX + barWidth + barMargin
  const textY = padding + (containerHeight + textSize / 2)
  svg += `<text x="${textX}" y="${textY}" font-size="${textSize}" fill="${textColor}" letter-spacing="-${0.03 * textSize}">hapai</text>`

  svg += '</svg>'
  return svg
}

async function generateLogo(filename, lightMode) {
  try {
    const svg = generateSVG(lightMode)
    const outputPath = path.join(publicDir, filename)

    await sharp(Buffer.from(svg))
      .png()
      .toFile(outputPath)

    console.log(`✓ Generated ${filename}`)
  } catch (error) {
    console.error(`✗ Error generating ${filename}:`, error.message)
    process.exit(1)
  }
}

async function main() {
  console.log('Generating logo PNGs...\n')
  await generateLogo('logo-light.png', true)
  await generateLogo('logo-dark.png', false)
  console.log('\n✓ All logos generated successfully')
}

main()
