const fs = require('node:fs/promises');
const path = require('node:path');

// A path stored in the database is only ever served from inside the upload folder.
function resolveInside(uploadDir, videoPath) {
  const root = path.resolve(uploadDir);
  const file = path.resolve(root, path.basename(videoPath));
  return file.startsWith(root + path.sep) ? file : null;
}

async function discard(file) {
  if (file) await fs.unlink(file.path ?? file).catch(() => {});
}

// MP4 files carry an 'ftyp' box right at the start.
async function looksLikeMp4(filePath) {
  const fd = await fs.open(filePath, 'r');
  try {
    const head = Buffer.alloc(12);
    const { bytesRead } = await fd.read(head, 0, 12, 0);
    return bytesRead >= 12 && head.toString('latin1', 4, 8) === 'ftyp';
  } finally {
    await fd.close();
  }
}

// Reads the length from the 'mvhd' box inside 'moov'. Returns 0 if it is not there.
async function mp4DurationSec(filePath) {
  const fd = await fs.open(filePath, 'r');
  try {
    const { size } = await fd.stat();
    const header = async (offset) => {
      const buf = Buffer.alloc(16);
      const { bytesRead } = await fd.read(buf, 0, 16, offset);
      if (bytesRead < 8) return null;
      let boxSize = buf.readUInt32BE(0);
      let headSize = 8;
      if (boxSize === 1 && bytesRead >= 16) {
        boxSize = Number(buf.readBigUInt64BE(8));
        headSize = 16;
      } else if (boxSize === 0) {
        boxSize = size - offset;
      }
      return { type: buf.toString('latin1', 4, 8), start: offset, headSize, end: offset + boxSize };
    };
    const find = async (from, to, wanted) => {
      let offset = from;
      while (offset + 8 <= to) {
        const box = await header(offset);
        if (!box || box.end <= offset) return null;
        if (box.type === wanted) return box;
        offset = box.end;
      }
      return null;
    };
    const moov = await find(0, size, 'moov');
    const mvhd = moov && (await find(moov.start + moov.headSize, moov.end, 'mvhd'));
    if (!mvhd) return 0;
    const body = Buffer.alloc(32);
    await fd.read(body, 0, 32, mvhd.start + mvhd.headSize);
    const version = body[0];
    const timescale = version === 1 ? body.readUInt32BE(20) : body.readUInt32BE(12);
    const duration = version === 1 ? Number(body.readBigUInt64BE(24)) : body.readUInt32BE(16);
    return timescale > 0 ? Math.round(duration / timescale) : 0;
  } catch {
    return 0;
  } finally {
    await fd.close();
  }
}

module.exports = { resolveInside, discard, looksLikeMp4, mp4DurationSec };
