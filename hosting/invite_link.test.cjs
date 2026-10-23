const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const html = fs.readFileSync(path.join(__dirname, "public/index.html"), "utf8");
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];

function loadInvite(
  userAgent,
  pathname = "/invite/abc123",
  navigatorOverrides = {},
) {
  const elements = new Map();
  const element = (key) => {
    if (!elements.has(key)) {
      const listeners = {};
      elements.set(key, {
        listeners,
        addEventListener(event, handler) {
          listeners[event] = handler;
        },
      });
    }
    return elements.get(key);
  };
  vm.runInNewContext(script, {
    navigator: { userAgent, ...navigatorOverrides },
    window: {
      location: {
        pathname,
        origin: "https://splitpay-c7905.web.app",
        host: "splitpay-c7905.web.app",
        replace() {
          assert.fail("Must not automatically redirect to a store");
        },
      },
      setTimeout() {
        assert.fail("Must not schedule a store redirect");
      },
    },
    document: { getElementById: element, querySelector: element },
  });
  return element;
}

test("iOS opens the installed app with the invite code, without a store redirect", () => {
  const element = loadInvite("iPhone");
  assert.equal(element("open-link").href, "dimeflow:///invite/ABC123");
  assert.equal(element("open-link").hidden, false);
  assert.match(element("store-link").href, /^https:\/\/apps.apple.com\//);
});

test("Android targets the installed package and preserves the invite code", () => {
  const element = loadInvite("Android");
  assert.equal(
    element("open-link").href,
    "intent://splitpay-c7905.web.app/invite/ABC123#Intent;scheme=https;package=com.splitpay.expensetracker;end",
  );
  assert.equal(element("open-link").hidden, false);
  assert.match(element("store-link").href, /^https:\/\/play.google.com\//);
});

test("desktop does not offer an app launch and invalid links do not offer installation", () => {
  assert.equal(loadInvite("Macintosh")("open-link").hidden, true);
  assert.equal(loadInvite("iPhone", "/invite/")("store-link").hidden, true);
  assert.equal(loadInvite("iPhone", "/invite/")("copy-code").hidden, true);
});

test("copy code writes only the invite code to the clipboard", async () => {
  let copiedText;
  const element = loadInvite("iPhone", "/invite/abc123", {
    clipboard: {
      async writeText(text) {
        copiedText = text;
      },
    },
  });
  await element("copy-code").listeners.click();
  assert.equal(copiedText, "ABC123");
  assert.equal(
    element("status").textContent,
    "Invite code copied. Send it to your group.",
  );
});

test("clipboard failure directs users to the displayed code", async () => {
  const element = loadInvite("iPhone");
  await element("copy-code").listeners.click();
  assert.equal(
    element("status").textContent,
    "Copy isn’t available here. Select and copy the invite code shown above.",
  );
});
