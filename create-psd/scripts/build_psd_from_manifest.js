const fs = require('fs');
const path = require('path');
const { createCanvas, loadImage } = require('canvas');
const ag = require('ag-psd');

ag.initializeCanvas(createCanvas);

function hexToRgb(hex) {
  const match = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex || '#000000');
  return match ? { r: parseInt(match[1], 16), g: parseInt(match[2], 16), b: parseInt(match[3], 16) } : { r: 0, g: 0, b: 0 };
}

function fontCss(item) {
  const weight = item.weight === 'bold' ? '700' : '400';
  const family = item.fontFamily || 'Arial';
  return `${weight} ${item.fontSize}px ${family}`;
}

async function canvasFromImage(file, width, height) {
  const canvas = createCanvas(width, height);
  const context = canvas.getContext('2d');
  const image = await loadImage(file);
  context.clearRect(0, 0, width, height);
  context.drawImage(image, 0, 0, width, height);
  return canvas;
}

async function main() {
  const manifestPath = process.argv[2];
  const outputPath = process.argv[3];
  if (!manifestPath || !outputPath) {
    throw new Error('Usage: node build_psd_from_manifest.js <manifest.json> <output.psd>');
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const width = manifest.canvas.width;
  const height = manifest.canvas.height;
  const children = [];
  const composite = createCanvas(width, height);
  const compositeContext = composite.getContext('2d');

  for (const layer of manifest.layers || []) {
    const canvas = await canvasFromImage(layer.path, layer.width || width, layer.height || height);
    children.push({
      name: layer.name,
      left: layer.x || 0,
      top: layer.y || 0,
      opacity: layer.opacity == null ? 255 : layer.opacity,
      canvas,
    });
    compositeContext.drawImage(canvas, layer.x || 0, layer.y || 0);
  }

  for (const item of manifest.texts || []) {
    const textCanvas = createCanvas(width, height);
    const context = textCanvas.getContext('2d');
    context.font = fontCss(item);
    context.fillStyle = item.color || '#000000';
    context.textBaseline = 'top';
    context.fillText(item.content, item.x, item.y);
    const metrics = context.measureText(item.content);
    const baselineY = item.y + item.fontSize;
    children.push({
      name: item.name,
      left: 0,
      top: 0,
      canvas: textCanvas,
      text: {
        text: item.content,
        transform: [1, 0, 0, 1, item.x, baselineY],
        left: item.x,
        top: item.y,
        right: Math.ceil(item.x + metrics.width + 8),
        bottom: Math.ceil(item.y + item.fontSize * 1.25),
        shapeType: 'point',
        style: {
          font: { name: item.font || 'ArialMT' },
          fontSize: item.fontSize,
          fillColor: hexToRgb(item.color),
        },
        paragraphStyle: { justification: item.justification || 'left' },
      },
    });
    compositeContext.font = fontCss(item);
    compositeContext.fillStyle = item.color || '#000000';
    compositeContext.textBaseline = 'top';
    compositeContext.fillText(item.content, item.x, item.y);
  }

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  const psd = { width, height, canvas: composite, children };
  fs.writeFileSync(outputPath, ag.writePsdBuffer(psd, { invalidateTextLayers: true }));
  const previewPath = outputPath.replace(/\.psd$/i, '_preview.png');
  fs.writeFileSync(previewPath, composite.toBuffer('image/png'));
  console.log(JSON.stringify({ outputPath, previewPath, width, height, layers: children.length }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
