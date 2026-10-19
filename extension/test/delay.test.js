import { test } from "node:test";
import assert from "node:assert/strict";
import "../src/lib/delay.js";

const { nextDelayMs, MIN_DELAY_MS, MAX_DELAY_MS } = globalThis.SeeraLib.delay;

test("delay stays within 60-180 s", () => {
  assert.equal(MIN_DELAY_MS, 60000);
  assert.equal(MAX_DELAY_MS, 180000);
  assert.equal(nextDelayMs(0), 60000);
  assert.equal(nextDelayMs(() => 0), 60000);
  const high = nextDelayMs(0.999);
  assert.ok(high >= 179000 && high <= 180000, String(high));
  assert.ok(nextDelayMs(() => 0.999) <= 180000);
  assert.equal(nextDelayMs(1), 180000);
  assert.equal(nextDelayMs(5), 180000);
  assert.equal(nextDelayMs(-1), 60000);
});

test("default random source stays in bounds", () => {
  for (let i = 0; i < 200; i += 1) {
    const ms = nextDelayMs();
    assert.ok(ms >= 60000 && ms <= 180000, String(ms));
  }
});
