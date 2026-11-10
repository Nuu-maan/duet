import assert from 'node:assert/strict';
import test from 'node:test';

import { MESSAGES, eventPush, localTime, plan, previousDay } from '../src/rules.js';

const IST = 330;
// 2026-11-10 at the given India time.
const at = (hour, minute = 0) => Date.UTC(2026, 10, 10, hour, minute) - IST * 60000;
const first = () => 0;
const last = () => 0.999;

function pair(overrides = {}) {
  return {
    devices: {
      me: { token: 't-me', tz: IST, name: 'Maya', birthday: '2001-03-04' },
      her: { token: 't-her', tz: IST, name: 'Arjun', birthday: '2002-06-07' },
    },
    streak: { count: 5, lastDay: '2026-11-09' },
    daily: {},
    notified: {},
    nudges: {},
    countdowns: {},
    ...overrides,
  };
}

const kinds = (pushes) => pushes.map((p) => `${p.uid}:${p.kind}`);

test('localTime uses the person own clock and day', () => {
  assert.deepEqual(localTime(Date.UTC(2026, 10, 10, 20, 0), IST), { day: '2026-11-11', minutes: 90 });
  assert.equal(previousDay('2026-03-01'), '2026-02-28');
});

test('nothing is sent before 7 pm or in quiet hours', () => {
  assert.deepEqual(plan(pair(), at(18, 59), first), []);
  assert.deepEqual(plan(pair(), at(23, 5), first), []);
  assert.deepEqual(plan(pair(), at(7, 30), first), []);
});

test('the 7 pm nudge goes only to whoever has not answered, once a day', () => {
  const data = pair({ daily: { '2026-11-10': { answers: { me: { q0: 'hi' } } } } });
  const pushes = plan(data, at(19, 5), first);
  assert.deepEqual(kinds(pushes), ['her:nudge']);
  assert.equal(pushes[0].channel, 'streak');
  assert.deepEqual(pushes[0].open, { open: 'daily' });
  assert.equal(pushes[0].marks['her/nudge'], '2026-11-10');

  data.notified = { her: { nudge: '2026-11-10' } };
  assert.deepEqual(plan(data, at(19, 20), first), []);
});

test('a skipped or empty answer does not count as answered', () => {
  const data = pair({ daily: { '2026-11-10': { answers: { me: { q0: '' }, her: {} } } } });
  assert.deepEqual(kinds(plan(data, at(19, 5), first)), ['me:nudge', 'her:nudge']);
});

test('streak about to end uses the live streak number and stops once answered', () => {
  const data = pair();
  const pushes = plan(data, at(21, 30), first);
  assert.deepEqual(kinds(pushes), ['me:ending', 'her:ending']);
  assert.equal(pushes[0].body, '🔥 5 days and counting… unless you forget tonight.');

  data.daily = { '2026-11-10': { answers: { her: { q1: 'x' } } } };
  assert.deepEqual(kinds(plan(data, at(21, 45), first)), ['me:ending']);
});

test('no ending warning when there is no streak to lose', () => {
  assert.deepEqual(plan(pair({ streak: { count: 1, lastDay: '2026-11-09' } }), at(21, 45), first), []);
  assert.deepEqual(plan(pair({ streak: { count: 9, lastDay: '2026-11-07' } }), at(21, 45), first), []);
});

test('a milestone is announced once to both, on the day it is reached', () => {
  const day = { answers: { me: { q0: 'a' }, her: { q0: 'b' } } };
  const data = pair({ streak: { count: 7, lastDay: '2026-11-10' }, daily: { '2026-11-10': day } });
  const pushes = plan(data, at(15), first);
  assert.deepEqual(kinds(pushes), ['me:milestone', 'her:milestone']);
  assert.equal(pushes[0].title, '7-day streak! 🔥');

  data.notified = { me: { milestone: 7 }, her: { milestone: 7 } };
  assert.deepEqual(plan(data, at(16), first), []);
  assert.deepEqual(plan(pair({ streak: { count: 8, lastDay: '2026-11-10' }, daily: { '2026-11-10': day } }), at(15), first), []);
});

test('consecutive messages differ, and the choice is remembered', () => {
  const data = pair({ notified: { her: { last: { nudge: 0 } }, me: { last: { nudge: 4 } } } });
  const [me, her] = plan(data, at(19, 5), first);
  assert.equal(her.body, MESSAGES.nudge[1].replace('{name}', 'Maya'));
  assert.equal(her.marks['her/last/nudge'], 1);
  assert.equal(me.body, MESSAGES.nudge[0]);
});

test('lines written by the friend are mixed in for streak reminders', () => {
  const data = pair({
    daily: { '2026-11-10': { answers: { me: { q0: 'x' } } } },
    nudges: { her: { b: { text: 'Wake up, sleepyhead 😴 {n} days!' }, a: { text: '' } } },
  });
  const [custom] = plan(data, at(21, 40), first);
  assert.equal(custom.body, 'Wake up, sleepyhead 😴 5 days!');
  assert.equal(custom.marks['her/last/custom'], 0);

  const [builtIn] = plan(data, at(21, 40), last);
  assert.ok(MESSAGES.ending.some((m) => builtIn.body === m.replace('{n}', '5').replace('{name}', 'Maya')));
});

test('switches turn a group off; a missing token means no push', () => {
  const data = pair();
  data.devices.her.streak = false;
  delete data.devices.me.token;
  assert.deepEqual(plan(data, at(21, 40), first), []);
});

test('birthday and countdown fire once, after 9 am', () => {
  const data = pair({
    daily: { '2026-11-10': { answers: { me: { q0: 'a' }, her: { q0: 'b' } } } },
    countdowns: { c1: { title: 'Trip', date: '2026-11-10' }, c2: { title: 'Later', date: '2026-12-01' } },
  });
  data.devices.her.birthday = '2002-11-10';
  assert.deepEqual(plan(data, at(8, 30), first), []);
  const pushes = plan(data, at(9, 5), first);
  assert.deepEqual(kinds(pushes), ['me:birthday', 'me:countdown', 'her:countdown']);
  assert.equal(pushes[0].body, "🎂 It's Arjun's birthday today!");
  assert.equal(pushes[1].body, "🎉 Today's the day: Trip");
});

test('an answer tells the friend it is their turn, once a day, then just that you answered', () => {
  const data = pair();
  const event = { kind: 'answered', day: '2026-11-10', slot: 1 };
  const [waiting] = eventPush(data, 'me', event, at(14), first);
  assert.equal(`${waiting.uid}:${waiting.kind}`, 'her:waiting');
  assert.equal(waiting.marks['her/waiting'], '2026-11-10');

  data.notified = { her: { waiting: '2026-11-10' } };
  const [answered] = eventPush(data, 'me', event, at(14, 5), first);
  assert.equal(answered.kind, 'answered');
  assert.deepEqual(answered.open, { open: 'thread', day: '2026-11-10', slot: '1' });
  assert.ok(!answered.body.includes('{'));
});

test('a chat message shows its text, trimmed, and collapses per thread', () => {
  const [push] = eventPush(pair(), 'her', { kind: 'message', day: '2026-11-10', slot: 2, text: 'x'.repeat(300) }, at(14), first);
  assert.equal(push.uid, 'me');
  assert.equal(push.title, 'Arjun');
  assert.equal(push.body.length, 140);
  assert.equal(push.tag, 'chat-2026-11-10-2');
  assert.deepEqual(eventPush(pair(), 'her', { kind: 'message', text: '' }, at(14), first), []);
});

test('a game move names the game and collapses per game', () => {
  const [push] = eventPush(pair(), 'me', { kind: 'move', game: 'reversi', name: 'Reversi' }, at(14), first);
  assert.equal(push.body, 'Maya made a move in Reversi. Your turn 🎲');
  assert.equal(push.tag, 'game-reversi');
  assert.deepEqual(push.open, { open: 'game', game: 'reversi' });
});

test('events respect quiet hours, switches and unknown kinds', () => {
  const move = { kind: 'move', game: 'reversi', name: 'Reversi' };
  assert.deepEqual(eventPush(pair(), 'me', move, at(23, 30), first), []);
  const data = pair();
  data.devices.her.games = false;
  assert.deepEqual(eventPush(data, 'me', move, at(14), first), []);
  assert.deepEqual(eventPush(pair(), 'me', { kind: 'nope' }, at(14), first), []);
  assert.deepEqual(eventPush({ devices: { me: { token: 't' } } }, 'me', move, at(14), first), []);
});
