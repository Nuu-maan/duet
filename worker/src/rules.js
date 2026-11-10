// Pure decision rules: no network, no clock, no randomness of their own.

export const MILESTONES = [2, 7, 14, 30, 50, 100, 365];

const NUDGE_AT = 19 * 60;
const ENDING_AT = 21 * 60 + 30;
const DAY_EVENTS_AT = 9 * 60;
const QUIET_FROM = 23 * 60;
const QUIET_UNTIL = 8 * 60;

export const MESSAGES = {
  nudge: [
    'Three fresh questions are waiting. Two minutes, tops 👀',
    '{name} might already be answering. Just saying.',
    "Today's questions won't answer themselves 🙃",
    'Psst. Your daily three are getting lonely.',
    'One tap, three questions, zero excuses ✨',
  ],
  ending: [
    '🔥 {n} days and counting… unless you forget tonight.',
    'Your streak is sweating. Answer one question to save it 🥵',
    "Don't let {n} days go up in smoke 🔥",
    'Not long left to keep the fire alive. Go go go!',
    '{name} is counting on you. So is the flame 🔥',
    'A {n}-day streak is a terrible thing to waste.',
  ],
  waiting: [
    '{name} did their part. The streak needs you now 👉',
    '{name} answered today. Your move 🔥',
    'Half the streak is done. Guess who the other half is?',
  ],
  milestone: [
    "🔥 It's official: a {n}-day streak! You two are on fire.",
    "{n} days in a row. That's commitment 🏆",
    '{n} days! That deserves a little dance 💃',
  ],
  answered: [
    '{name} answered a question. Answer to see what they said 👀',
    "New answer from {name}. It's locked until you answer too 🔒",
    '{name} just spilled. Your turn!',
  ],
  move: [
    '{name} made a move in {game}. Your turn 🎲',
    '{game}: {name} is waiting, and probably gloating.',
    'Your move in {game}. No pressure 😏',
  ],
  birthday: ["🎂 It's {name}'s birthday today!"],
  countdown: ["🎉 Today's the day: {title}"],
};

const TITLES = {
  nudge: 'Daily three ✨',
  ending: 'Streak in danger 🔥',
  waiting: '{name} is waiting',
  milestone: '{n}-day streak! 🔥',
  answered: '{name} answered',
  move: '{game}',
  birthday: 'Birthday! 🎂',
  countdown: "It's today! 🎉",
};

const CHANNELS = {
  nudge: 'streak',
  ending: 'streak',
  waiting: 'streak',
  milestone: 'streak',
  answered: 'friend',
  message: 'friend',
  birthday: 'friend',
  countdown: 'friend',
  move: 'games',
};

// The other person may write their own lines for these.
const CUSTOM_KINDS = ['nudge', 'ending', 'waiting'];

const two = (n) => String(n).padStart(2, '0');

export function dayKey(ms) {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${two(d.getUTCMonth() + 1)}-${two(d.getUTCDate())}`;
}

export function previousDay(day) {
  return dayKey(Date.parse(`${day}T00:00:00Z`) - 86400000);
}

/** The person's own calendar day and minutes past midnight. */
export function localTime(nowMs, tzMinutes) {
  const shifted = nowMs + (tzMinutes || 0) * 60000;
  const d = new Date(shifted);
  return { day: dayKey(shifted), minutes: d.getUTCHours() * 60 + d.getUTCMinutes() };
}

const isQuiet = (minutes) => minutes >= QUIET_FROM || minutes < QUIET_UNTIL;

export function hasAnswered(data, day, uid) {
  const answers = data.daily?.[day]?.answers?.[uid];
  return Object.values(answers ?? {}).some((v) => typeof v === 'string' && v !== '');
}

function aliveStreak(streak, day) {
  if (!streak || typeof streak.count !== 'number') return 0;
  return streak.lastDay === day || streak.lastDay === previousDay(day) ? streak.count : 0;
}

const fill = (text, vars) =>
  text.replace(/\{(\w+)\}/g, (whole, key) => (key in vars ? String(vars[key]) : whole));

function friendOf(data, uid) {
  return Object.keys(data.devices ?? {}).find((other) => other !== uid);
}

function build(data, uid, kind, vars, open, rng, extraMarks = {}) {
  const custom = Object.keys(data.nudges?.[uid] ?? {})
    .sort()
    .map((id) => data.nudges[uid][id]?.text)
    .filter((text) => typeof text === 'string' && text !== '');
  const useCustom = CUSTOM_KINDS.includes(kind) && custom.length > 0 && rng() < 2 / 3;
  const pool = useCustom ? custom : MESSAGES[kind];
  const poolName = useCustom ? 'custom' : kind;
  const last = data.notified?.[uid]?.last?.[poolName];
  let index = Math.floor(rng() * pool.length);
  if (pool.length > 1 && index === last) index = (index + 1) % pool.length;
  return {
    uid,
    kind,
    channel: CHANNELS[kind],
    title: fill(TITLES[kind], vars),
    body: fill(pool[index], vars),
    open,
    marks: { [`${uid}/last/${poolName}`]: index, ...extraMarks },
  };
}

/** Timed notifications: run on a schedule, sends each at most once a day. */
export function plan(data, nowMs, rng = Math.random) {
  const out = [];
  for (const [uid, device] of Object.entries(data.devices ?? {})) {
    if (!device?.token) continue;
    const { day, minutes } = localTime(nowMs, device.tz);
    if (isQuiet(minutes)) continue;
    const flags = data.notified?.[uid] ?? {};
    const friendUid = friendOf(data, uid);
    const friend = data.devices[friendUid] ?? {};
    const name = friend.name || 'Your friend';
    const streak = data.streak;
    const n = aliveStreak(streak, day);

    if (device.streak !== false) {
      const answered = hasAnswered(data, day, uid);
      if (!answered && n >= 2 && minutes >= ENDING_AT && flags.ending !== day) {
        out.push(
          build(data, uid, 'ending', { name, n }, { open: 'daily' }, rng, { [`${uid}/ending`]: day }),
        );
      } else if (!answered && minutes >= NUDGE_AT && minutes < ENDING_AT && flags.nudge !== day) {
        out.push(
          build(data, uid, 'nudge', { name, n }, { open: 'daily' }, rng, { [`${uid}/nudge`]: day }),
        );
      }
      if (streak?.lastDay === day && MILESTONES.includes(n) && flags.milestone !== n) {
        out.push(
          build(data, uid, 'milestone', { name, n }, { open: 'streak' }, rng, {
            [`${uid}/milestone`]: n,
          }),
        );
      }
    }

    if (device.friend !== false && minutes >= DAY_EVENTS_AT) {
      const born = friend.birthday;
      if (typeof born === 'string' && born.slice(5) === day.slice(5) && flags.birthday !== day) {
        out.push(build(data, uid, 'birthday', { name }, { open: 'home' }, rng, { [`${uid}/birthday`]: day }));
      }
      const titles = Object.values(data.countdowns ?? {})
        .filter((c) => c?.date === day && typeof c.title === 'string')
        .map((c) => c.title);
      if (titles.length > 0 && flags.countdown !== day) {
        out.push(
          build(data, uid, 'countdown', { title: titles.join(', ') }, { open: 'home' }, rng, {
            [`${uid}/countdown`]: day,
          }),
        );
      }
    }
  }
  return out;
}

const text = (value, max) => (typeof value === 'string' ? value.slice(0, max) : '');

/** Instant notifications: something the other person just did. */
export function eventPush(data, fromUid, event, nowMs, rng = Math.random) {
  const uid = friendOf(data, fromUid);
  const device = data.devices?.[uid];
  if (!device?.token) return [];
  const { day, minutes } = localTime(nowMs, device.tz);
  if (isQuiet(minutes)) return [];
  const name = data.devices[fromUid]?.name || 'Your friend';
  const flags = data.notified?.[uid] ?? {};

  if (event.kind === 'answered') {
    if (device.streak !== false && !hasAnswered(data, day, uid) && flags.waiting !== day) {
      return [
        build(data, uid, 'waiting', { name, n: aliveStreak(data.streak, day) }, { open: 'daily' }, rng, {
          [`${uid}/waiting`]: day,
        }),
      ];
    }
    if (device.friend === false) return [];
    const open = { open: 'thread', day: text(event.day, 10), slot: String(Number(event.slot) || 0) };
    return [build(data, uid, 'answered', { name }, open, rng)];
  }

  if (event.kind === 'message') {
    const body = text(event.text, 140);
    if (device.friend === false || body === '') return [];
    const slot = String(Number(event.slot) || 0);
    return [
      {
        uid,
        kind: 'message',
        channel: CHANNELS.message,
        title: name,
        body,
        open: { open: 'thread', day: text(event.day, 10), slot },
        tag: `chat-${text(event.day, 10)}-${slot}`,
        marks: {},
      },
    ];
  }

  if (event.kind === 'move') {
    const game = text(event.name, 40);
    const id = text(event.game, 40);
    if (device.games === false || game === '' || id === '') return [];
    return [{ ...build(data, uid, 'move', { name, game }, { open: 'game', game: id }, rng), tag: `game-${id}` }];
  }

  return [];
}
