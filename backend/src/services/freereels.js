// FreeReels on the Series Open API, turned into the shapes the app already
// reads (platform, drama, page, episode links). FreeReels names a series with
// a string like "m4FzR2J0iQ"; the controller swaps that for our own number.
const PLATFORM_ID = 19;
const PLATFORM_NAME = 'FreeReels';
const BASE = '/api/platform/freereels';

const paths = {
  access: '/api/me/access',
  thai: `${BASE}/thai`,
  search: `${BASE}/search`,
  drama: (seriesId) => `${BASE}/official/drama/${encodeURIComponent(seriesId)}`,
  play: (seriesId, ep) => `${BASE}/official/drama/${encodeURIComponent(seriesId)}/play/${ep}`,
};

const isThaiDub = (title) => /พากย์/.test(String(title ?? ''));

function splitGenres(value) {
  if (Array.isArray(value)) return value.map(String).filter(Boolean);
  return String(value ?? '')
    .split(',')
    .map((g) => g.trim())
    .filter(Boolean);
}

// The one platform this key can use, in the app's platform shape.
function toPlatforms(access) {
  const entry = (access?.platforms ?? []).find((p) => p.platform_id === PLATFORM_ID);
  return {
    items: [{ id: PLATFORM_ID, name: PLATFORM_NAME, drama_count: 0, has_access: Boolean(entry) }],
  };
}

// A list or search item: { series_id, title, cover, episode_count, genre, description }.
function toDrama(item, id) {
  return {
    id,
    title: String(item.title ?? ''),
    description: item.description || null,
    episode_count: Number(item.episode_count) || 0,
    genres: splitGenres(item.genre),
    poster: item.cover || null,
    thai_dub: isThaiDub(item.title),
    thai_sub: false,
  };
}

function toPage(body, ids) {
  const pageSize = Number(body.page_size) || 20;
  const items = (body.items ?? []).filter((i) => ids.has(i.series_id));
  return {
    items: items.map((i) => toDrama(i, ids.get(i.series_id))),
    page: Number(body.page) || 1,
    total_pages: Math.max(1, Math.ceil((Number(body.total) || 0) / pageSize)),
  };
}

// The detail reply nests the series under data.data.info; an unknown id
// comes back as an empty object.
function detailInfo(body) {
  const info = body?.data?.data?.info;
  return info && info.id ? info : null;
}

function toDramaFromDetail(info, id) {
  const subtitles = info.episode?.subtitle_list ?? [];
  return {
    ...toDrama(
      {
        title: info.name,
        description: info.desc,
        episode_count: info.episode_count,
        genre: info.content_tags,
        cover: info.cover,
      },
      id,
    ),
    thai_sub: subtitles.some((s) => String(s.language).startsWith('th')),
  };
}

// One episode's stream as { episode_no, parts: [{ url, subtitles }] }. The app
// looks for language "th", so "th-TH" is shortened.
function toEpisode(body, episodeNo) {
  const data = body?.data?.data ?? {};
  const url = data.m3u8_url || data.external_audio_h264_m3u8;
  if (!url) return null;
  const subtitles = (data.subtitle_list ?? [])
    .filter((s) => s.vtt)
    .map((s) => ({
      language: String(s.language).split('-')[0],
      url: s.vtt,
      forced: false,
    }));
  return { episode_no: Number(data.episode_number) || episodeNo, parts: [{ url, subtitles }] };
}

module.exports = {
  PLATFORM_ID,
  paths,
  toPlatforms,
  toDrama,
  toPage,
  detailInfo,
  toDramaFromDetail,
  toEpisode,
};
