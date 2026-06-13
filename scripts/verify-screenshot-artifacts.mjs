import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { inflateSync } from "node:zlib";
import { formatValidationBlocker } from "./validation-blockers.mjs";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const inputs = process.argv.slice(2);
const roots = inputs.length ? inputs.map((value) => resolve(value)) : [join(repoRoot, "docs", "ui-artifacts")];

const sensitivePattern =
  /\/Users\/[^/\s`"<>)]|\/var\/folders\/[^/\s`"<>)]|\/private\/var\/folders\/[^/\s`"<>)]|OPENAI_API_KEY|ANTHROPIC_AUTH_TOKEN|DASHSCOPE_API_KEY|API[_-]?KEY[=:]|TOKEN[=:]|SECRET[=:]|PASSWORD[=:]|sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}/i;

function fail(message) {
  console.error(`screenshot verification failed: ${message}`);
  process.exit(1);
}

function collectPngs(path) {
  if (!existsSync(path)) {
    fail(`missing path: ${path}`);
  }
  const stats = statSync(path);
  if (stats.isFile()) {
    return path.endsWith(".png") ? [path] : [];
  }
  if (!stats.isDirectory()) {
    return [];
  }
  return readdirSync(path, { withFileTypes: true }).flatMap((entry) => {
    const child = join(path, entry.name);
    if (entry.isDirectory()) {
      return collectPngs(child);
    }
    return entry.isFile() && child.endsWith(".png") ? [child] : [];
  });
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

function parsePng(buffer, path) {
  const signature = "89504e470d0a1a0a";
  if (buffer.subarray(0, 8).toString("hex") !== signature) {
    fail(`${path} is not a PNG file`);
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let interlace = 0;
  const idatChunks = [];

  while (offset < buffer.length) {
    if (offset + 12 > buffer.length) fail(`${path} has a truncated PNG chunk`);
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString("ascii");
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    if (dataEnd + 4 > buffer.length) fail(`${path} has an invalid PNG chunk length`);
    const data = buffer.subarray(dataStart, dataEnd);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
      interlace = data[12];
    } else if (type === "IDAT") {
      idatChunks.push(data);
    } else if (type === "IEND") {
      break;
    }
    offset = dataEnd + 4;
  }

  if (width < 200 || height < 120) {
    fail(formatValidationBlocker(`invalid-capture: ${path} dimensions are too small: ${width}x${height}`));
  }
  if (bitDepth !== 8 || ![0, 2, 6].includes(colorType) || interlace !== 0) {
    fail(formatValidationBlocker(
      `invalid-capture: ${path} uses unsupported PNG format: bitDepth=${bitDepth}, colorType=${colorType}, interlace=${interlace}`,
    ));
  }

  const bytesPerPixel = colorType === 6 ? 4 : colorType === 2 ? 3 : 1;
  const rowBytes = width * bytesPerPixel;
  const inflated = inflateSync(Buffer.concat(idatChunks));
  if (inflated.length < (rowBytes + 1) * height) {
    fail(`${path} has truncated image data`);
  }

  const pixels = Buffer.alloc(rowBytes * height);
  for (let y = 0; y < height; y += 1) {
    const filter = inflated[y * (rowBytes + 1)];
    const srcStart = y * (rowBytes + 1) + 1;
    const dstStart = y * rowBytes;
    for (let x = 0; x < rowBytes; x += 1) {
      const raw = inflated[srcStart + x];
      const left = x >= bytesPerPixel ? pixels[dstStart + x - bytesPerPixel] : 0;
      const up = y > 0 ? pixels[dstStart + x - rowBytes] : 0;
      const upLeft = y > 0 && x >= bytesPerPixel ? pixels[dstStart + x - rowBytes - bytesPerPixel] : 0;
      let value;
      switch (filter) {
        case 0:
          value = raw;
          break;
        case 1:
          value = raw + left;
          break;
        case 2:
          value = raw + up;
          break;
        case 3:
          value = raw + Math.floor((left + up) / 2);
          break;
        case 4:
          value = raw + paeth(left, up, upLeft);
          break;
        default:
          fail(`${path} has unsupported PNG filter ${filter}`);
      }
      pixels[dstStart + x] = value & 0xff;
    }
  }

  return { width, height, colorType, pixels, bytesPerPixel, rowBytes };
}

function validateVisualSignal(path, parsed) {
  const { width, height, colorType, pixels, bytesPerPixel, rowBytes } = parsed;
  const stepX = Math.max(1, Math.floor(width / 160));
  const stepY = Math.max(1, Math.floor(height / 160));
  let sampleCount = 0;
  let opaqueCount = 0;
  let brightnessSum = 0;
  let brightnessSquaredSum = 0;

  for (let y = 0; y < height; y += stepY) {
    for (let x = 0; x < width; x += stepX) {
      const index = y * rowBytes + x * bytesPerPixel;
      let r;
      let g;
      let b;
      let alpha = 255;
      if (colorType === 0) {
        r = g = b = pixels[index];
      } else {
        r = pixels[index];
        g = pixels[index + 1];
        b = pixels[index + 2];
        if (colorType === 6) alpha = pixels[index + 3];
      }
      if (alpha > 20) opaqueCount += 1;
      const brightness = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
      brightnessSum += brightness;
      brightnessSquaredSum += brightness * brightness;
      sampleCount += 1;
    }
  }

  const mean = brightnessSum / sampleCount;
  const variance = Math.max(0, brightnessSquaredSum / sampleCount - mean * mean);
  const opaqueRatio = opaqueCount / sampleCount;
  if (opaqueRatio < 0.2) {
    fail(formatValidationBlocker(`transparent-capture: ${path} is mostly transparent`));
  }
  if (mean < 0.025) {
    fail(formatValidationBlocker(`black-capture: ${path} is near black`));
  }
  if (variance < 0.000015) {
    fail(formatValidationBlocker(`flat-capture: ${path} has near-zero visual variance`));
  }
}

const pngs = [...new Set(roots.flatMap(collectPngs))].sort();
if (pngs.length === 0) {
  fail(`no PNG files found under ${roots.join(", ")}`);
}

for (const png of pngs) {
  const buffer = readFileSync(png);
  if (sensitivePattern.test(buffer.toString("latin1"))) {
    fail(`${png} contains sensitive-looking binary strings`);
  }
  const parsed = parsePng(buffer, png);
  validateVisualSignal(png, parsed);
  console.log(`screenshot ok: ${png} (${parsed.width}x${parsed.height})`);
}

console.log(`screenshot verification passed: ${pngs.length} PNG artifact(s)`);
