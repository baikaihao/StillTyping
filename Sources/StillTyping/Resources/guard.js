"use strict";
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory;
  root.StillTypingGuardFactory = factory;
})(globalThis, function installStillTyping(win, options = {}) {
  const key = "__stillTypingGuard_v1";
  const owner = options.owner || "local-test";
  if (win[key]?.version === 1 && win[key].owner === owner) {
    win[key].configure(options);
    return win[key];
  }
  if (win[key]?.version === 1) win[key].dispose();

  const clock = options.now || (() => win.performance.now());
  let enabled = options.enabled !== false;
  let lease = options.leaseMilliseconds ?? 4000;
  let expires = lease === 0 ? Infinity : clock() + lease;
  let composing = new WeakSet();
  let held = null;
  let disposed = false;
  const listeners = [];

  function editable(event) {
    const path = typeof event.composedPath === "function" ? event.composedPath() : [event.target];
    for (const element of path) {
      if (!element || element.nodeType !== 1) continue;
      const tag = element.tagName?.toLowerCase();
      if (tag === "input") {
        const type = (element.type || "text").toLowerCase();
        return ["text", "search", "email", "url", "tel"].includes(type)
          && !element.disabled && !element.readOnly ? element : null;
      }
      if (tag === "textarea") return !element.disabled && !element.readOnly ? element : null;
      if (element.isContentEditable) return element;
    }
    return null;
  }
  function isEnter(event) {
    return event.key === "Enter" || event.code === "Enter" || event.code === "NumpadEnter" || event.keyCode === 13;
  }
  function active() { return enabled && !disposed && clock() < expires; }
  function stop(event, cancel = false) {
    event.stopImmediatePropagation();
    if (cancel && event.cancelable) event.preventDefault();
  }
  function listen(type, handler) {
    win.addEventListener(type, handler, true);
    listeners.push([type, handler]);
  }

  listen("compositionstart", event => {
    const element = editable(event);
    if (element) composing.add(element);
  });
  listen("compositionend", event => {
    const element = editable(event);
    if (element) composing.delete(element);
  });
  listen("keydown", event => {
    if (!isEnter(event)) return;
    const element = editable(event);
    if (!element) return;
    if (held?.element === element && event.repeat) {
      // Keep a held confirmation key from turning into submission after compositionend.
      stop(event, !event.isComposing && !composing.has(element));
      return;
    }
    if (!event.repeat) held = null; // A fresh physical press also heals a missing keyup.
    if (!active() || event.shiftKey || event.ctrlKey || event.altKey || event.metaKey) return;
    if (!(event.isComposing || composing.has(element) || event.keyCode === 229)) return;
    held = { element, code: event.code };
    // Do not cancel keydown: its native default may be the IME's text confirmation.
    stop(event);
  });
  listen("keypress", event => {
    if (!held || !isEnter(event) || editable(event) !== held.element) return;
    stop(event, !event.isComposing && !composing.has(held.element));
  });
  listen("keyup", event => {
    if (!held || !isEnter(event)) return;
    const sameElement = editable(event) === held.element;
    held = null;
    if (sameElement) stop(event, true);
  });
  listen("submit", event => {
    // Also guard an implicit native form submission associated with this confirmation.
    if (held && event.target?.contains?.(held.element)) stop(event, true);
  });
  listen("blur", event => {
    const element = editable(event);
    if (element) composing.delete(element);
    if (event.target === win || event.target === held?.element) held = null;
    if (event.target === win) composing = new WeakSet();
  });
  listen("pointerdown", () => { held = null; });
  listen("pagehide", () => { held = null; composing = new WeakSet(); });

  const api = {
    version: 1, owner,
    configure(next = {}) {
      if (typeof next.enabled === "boolean") enabled = next.enabled;
      if (typeof next.leaseMilliseconds === "number") lease = Math.max(0, next.leaseMilliseconds);
      expires = lease === 0 ? Infinity : clock() + lease;
    },
    dispose() {
      disposed = true;
      enabled = false;
      held = null;
      composing = new WeakSet();
      for (const [type, handler] of listeners) win.removeEventListener(type, handler, true);
      listeners.length = 0;
      if (win[key] === api) delete win[key];
    }
  };
  Object.defineProperty(win, key, { value: api, writable: true, configurable: true });
  return api;
});
