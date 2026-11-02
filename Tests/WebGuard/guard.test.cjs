const { test } = require('node:test');
const assert = require('node:assert/strict');
const install = require('../../Sources/StillTyping/Resources/guard.js');

function fixture(options = {}) {
  const listeners = new Map();
  const win = {
    performance: { now: () => 100 },
    addEventListener(type, fn) { const list = listeners.get(type) || []; list.push(fn); listeners.set(type, list); },
    removeEventListener(type, fn) { listeners.set(type, (listeners.get(type) || []).filter(item => item !== fn)); }
  };
  const editor = { nodeType: 1, tagName: 'INPUT', type: 'search', disabled: false, readOnly: false };
  const api = install(win, { leaseMilliseconds: 0, ...options });
  function fire(type, properties = {}) {
    const target = properties.target || editor;
    const event = { type, target, key: 'Enter', code: 'Enter', keyCode: 13, cancelable: true,
      isComposing: false, repeat: false, defaultPrevented: false, stopped: false,
      composedPath: () => [target, win],
      stopImmediatePropagation() { this.stopped = true; },
      preventDefault() { this.defaultPrevented = true; }, ...properties };
    for (const listener of listeners.get(type) || []) { listener(event); if (event.stopped) break; }
    return event;
  }
  return { win, editor, api, fire, listeners };
}

test('confirmation preserves the IME default and blocks both site keyboard phases', () => {
  const { fire } = fixture();
  fire('compositionstart');
  const down = fire('keydown', { isComposing: true, keyCode: 229 });
  assert.equal(down.stopped, true);
  assert.equal(down.defaultPrevented, false);
  fire('compositionend');
  assert.equal(fire('keyup').stopped, true);
  assert.equal(fire('keydown').stopped, false);
});

test('legacy Safari ordering uses 229 without relying on an arbitrary debounce', () => {
  const { fire } = fixture();
  fire('compositionstart'); fire('compositionend');
  assert.equal(fire('keydown', { keyCode: 229, isComposing: false }).stopped, true);
  fire('keyup');
  assert.equal(fire('keydown').stopped, false);
});

test('composing state alone protects an Enter when the browser omits isComposing', () => {
  const { fire } = fixture(); fire('compositionstart');
  assert.equal(fire('keydown').stopped, true);
});

test('normal Enter and explicit modifier shortcuts retain original behavior', () => {
  const { fire } = fixture();
  assert.equal(fire('keydown').stopped, false);
  fire('compositionstart');
  for (const modifier of ['shiftKey','ctrlKey','altKey','metaKey']) {
    assert.equal(fire('keydown', { [modifier]: true, isComposing: true }).stopped, false);
  }
});

test('auto-repeat cannot submit after the confirmation ends', () => {
  const { fire } = fixture();
  fire('keydown', { isComposing: true }); fire('compositionend');
  const repeated = fire('keydown', { repeat: true });
  assert.equal(repeated.stopped, true);
  assert.equal(repeated.defaultPrevented, true);
  fire('keyup');
  assert.equal(fire('keydown').stopped, false);
});

test('keypress and implicit form submission are guarded for the held confirmation', () => {
  const { fire, editor } = fixture();
  fire('keydown', { isComposing: true }); fire('compositionend');
  assert.equal(fire('keypress').defaultPrevented, true);
  assert.equal(fire('submit', { target: { contains: child => child === editor } }).defaultPrevented, true);
  fire('keyup');
  assert.equal(fire('submit', { target: { contains: () => true } }).defaultPrevented, false);
});

test('blur and missing keyup cannot poison the next input', () => {
  const { fire, win } = fixture(); fire('compositionstart');
  fire('keydown', { isComposing: true }); fire('compositionend');
  assert.equal(fire('keydown').stopped, false);
  fire('compositionstart'); fire('blur', { target: win });
  assert.equal(fire('keydown').stopped, false);
});

test('only editable controls are handled, including contenteditable and shadow paths', () => {
  const { fire } = fixture();
  for (const target of [
    { nodeType: 1, tagName: 'INPUT', type: 'password' },
    { nodeType: 1, tagName: 'INPUT', type: 'search', readOnly: true },
    { nodeType: 1, tagName: 'BUTTON' }
  ]) assert.equal(fire('keydown', { target, isComposing: true }).stopped, false);
  assert.equal(fire('keydown', { target: { nodeType: 1, tagName: 'DIV', isContentEditable: true }, isComposing: true }).stopped, true);
});

test('protection expires after an app crash and polling renews it idempotently', () => {
  let time = 0;
  const { win, fire, listeners } = fixture({ now: () => time, leaseMilliseconds: 4000, owner: 'test' });
  const listenerCount = [...listeners.values()].flat().length;
  time = 4001;
  assert.equal(fire('keydown', { isComposing: true }).stopped, false);
  install(win, { owner: 'test', enabled: true, leaseMilliseconds: 4000 });
  assert.equal([...listeners.values()].flat().length, listenerCount);
  assert.equal(fire('keydown', { isComposing: true }).stopped, true);
});

test('pause/dispose restore behavior without modifying input text', () => {
  const { editor, fire, api } = fixture();
  Object.defineProperty(editor, 'value', { get() { throw new Error('Input contents must never be read'); } });
  fire('compositionstart');
  api.configure({ enabled: false });
  assert.equal(fire('keydown', { isComposing: true }).stopped, false);
  api.configure({ enabled: true });
  assert.equal(fire('keydown', { isComposing: true }).stopped, true);
  api.dispose();
  assert.equal(fire('keydown', { isComposing: true }).stopped, false);
});
