const fs = require('node:fs/promises');
const path = require('node:path');

// A path stored in the database is only ever served from inside the upload folder.
function resolveInside(uploadDir, videoPath) {
  const root = path.resolve(uploadDir);
  const file = path.resolve(root, path.basename(videoPath));
  return file.startsWith(root + path.sep) ? file : null;
}

// Sample-entry codes of the video codecs a browser <video> can play from MP4.
const VIDEO_CODECS = new Set(['avc1', 'avc3', 'hvc1', 'hev1', 'av01', 'vp09', 'mp4v']);

// Walks the box headers of an MP4 (never the media data) and answers whether it
// holds a playable video track: an 'ftyp' box, a 'moov' with a 'trak' whose
// handler is 'vide' and whose sample description names a supported codec, and
// either media data ('mdat') or fragments ('moof', fragmented MP4).
async function inspectMp4(filePath) {
  const fd = await fs.open(filePath, 'r');
  try {
    const { size } = await fd.stat();
    const read = async (offset, length) => {
      const buf = Buffer.alloc(length);
      const { bytesRead } = await fd.read(buf, 0, length, offset);
      return buf.subarray(0, bytesRead);
    };
    const children = async (from, to) => {
      const boxes = [];
      let offset = from;
      while (offset + 8 <= to && boxes.length < 64) {
        const head = await read(offset, 16);
        if (head.length < 8) break;
        let boxSize = head.readUInt32BE(0);
        let headSize = 8;
        if (boxSize === 1 && head.length >= 16) {
          boxSize = Number(head.readBigUInt64BE(8));
          headSize = 16;
        } else if (boxSize === 0) {
          boxSize = to - offset;
        }
        if (boxSize < headSize || offset + boxSize > to) break;
        boxes.push({ type: head.toString('latin1', 4, 8), start: offset, body: offset + headSize, end: offset + boxSize });
        offset += boxSize;
      }
      return boxes;
    };
    const first = (boxes, type) => boxes.find((b) => b.type === type);

    const top = await children(0, size);
    if (top[0]?.type !== 'ftyp') return { valid: false, reason: 'not an MP4 file' };
    const moov = first(top, 'moov');
    if (!moov) return { valid: false, reason: 'the file has no movie header (moov)' };
    if (!first(top, 'mdat') && !first(top, 'moof')) {
      return { valid: false, reason: 'the file has no media data' };
    }
    for (const trak of (await children(moov.body, moov.end)).filter((b) => b.type === 'trak')) {
      const mdia = first(await children(trak.body, trak.end), 'mdia');
      if (!mdia) continue;
      const mdiaBoxes = await children(mdia.body, mdia.end);
      const hdlr = first(mdiaBoxes, 'hdlr');
      if (!hdlr || (await read(hdlr.body + 8, 4)).toString('latin1') !== 'vide') continue;
      const minf = first(mdiaBoxes, 'minf');
      const stbl = minf && first(await children(minf.body, minf.end), 'stbl');
      const stsd = stbl && first(await children(stbl.body, stbl.end), 'stsd');
      if (!stsd) continue;
      // full box header (4) + entry count (4) + entry size (4), then the entry type.
      const codec = (await read(stsd.body + 12, 4)).toString('latin1');
      if (VIDEO_CODECS.has(codec)) return { valid: true, codec };
      return { valid: false, reason: `unsupported video codec "${codec}"` };
    }
    return { valid: false, reason: 'the file has no video track' };
  } catch {
    return { valid: false, reason: 'the file could not be read as an MP4' };
  } finally {
    await fd.close();
  }
}

const looksLikeMp4 = async (filePath) => (await inspectMp4(filePath)).valid;

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

module.exports = { resolveInside, inspectMp4, looksLikeMp4, mp4DurationSec };
