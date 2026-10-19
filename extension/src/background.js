// Service worker: the apply loop (plan 3.2). Service workers sleep between
// events, so every piece of state lives in chrome.storage, never in globals.
import {
  APPLICATION_TIMEOUT_MS,
  CHECK_FILES,
  CLOSE_TAB_AFTER_MS,
  CONTENT_FILES,
  DEFAULT_ORIGIN,
  ERROR_BACKOFF_MS,
  FIRST_TICK_MINUTES,
  HISTORY_SIZE,
  IDLE_RETRY_MS,
  MAX_NAVIGATIONS,
  RATE_LIMIT_BACKOFF_MS,
  TICK_ALARM,
  WATCHDOG_MS,
  normaliseOrigin,
} from "./config.js";
import { ApiError, createApi } from "./api.js";
import "./lib/delay.js";

const { nextDelayMs } = globalThis.SeeraLib.delay;

const CURRENT_CLEARED = {
  currentApplicationId: null,
  currentApplication: null,
  currentTabId: null,
  currentStartedAt: null,
  currentPhase: null,
  currentNavigations: 0,
};

// Only guards against injecting twice into the same tab within one wake-up.
const injecting = new Set();

// --- storage helpers ---------------------------------------------------------

const getState = () => chrome.storage.local.get(null);
const setState = (patch) => chrome.storage.local.set(patch);

function apiFor(state) {
  return createApi({ origin: normaliseOrigin(state.origin), token: state.token });
}

function schedule(ms) {
  chrome.alarms.create(TICK_ALARM, { when: Date.now() + Math.max(ms, 1000) });
}

function nextLocalMidnight() {
  const d = new Date();
  d.setHours(24, 0, 5, 0);
  return d.getTime();
}

async function sessionGet() {
  try {
    const data = await chrome.storage.session.get("job");
    return data.job || {};
  } catch (_e) {
    return {};
  }
}

async function sessionSet(job) {
  try {
    await chrome.storage.session.set({ job });
  } catch (_e) {
    // session storage unavailable or full: data is fetched again next time
  }
}

async function sessionClear() {
  try {
    await chrome.storage.session.remove("job");
  } catch (_e) {
    // nothing cached
  }
}

// --- API errors --------------------------------------------------------------

async function handleApiError(error) {
  const e = error instanceof ApiError ? error : new ApiError(0, "network", String(error));
  if (e.status === 401) {
    await setState({ token: null, user: null, running: false, lastError: "unauthorized" });
    await chrome.alarms.clear(TICK_ALARM);
    return;
  }
  if (e.status === 403 || (e.status === 404 && e.code === "not_found")) {
    await setState({ running: false, lastError: e.code });
    await chrome.alarms.clear(TICK_ALARM);
    return;
  }
  if (e.status === 429 && e.code === "daily_cap_reached") {
    const until = nextLocalMidnight();
    await setState({ pausedUntil: until, lastError: "daily_cap_reached" });
    chrome.alarms.create(TICK_ALARM, { when: until });
    return;
  }
  if (e.status === 429) {
    await setState({ lastError: "rate_limited" });
    schedule(RATE_LIMIT_BACKOFF_MS);
    return;
  }
  await setState({ lastError: e.code || "network" });
  schedule(ERROR_BACKOFF_MS);
}

// --- profile and resume, fetched once per run -------------------------------

async function loadJobData(api) {
  const cache = await sessionGet();
  let { profile, resume } = cache;
  if (!profile) profile = await api.profile();
  if (!resume || cache.resumeId !== profile.resume_id) resume = await api.resumePdf();
  await sessionSet({ profile, resume, resumeId: profile.resume_id });
  return { profile, resume };
}

// --- the loop ------------------------------------------------------------------

async function tick() {
  const s = await getState();
  if (!s.running) return;

  if (s.pausedUntil && Date.now() < s.pausedUntil) {
    chrome.alarms.create(TICK_ALARM, { when: s.pausedUntil });
    return;
  }
  if (s.pausedUntil) await setState({ pausedUntil: null, lastError: null });

  if (s.currentApplicationId) {
    const tab = s.currentTabId ? await chrome.tabs.get(s.currentTabId).catch(() => null) : null;
    if (!tab) {
      await finish({ status: "failed", error: "tab_closed", details: {} }, { closeTab: false });
    } else if (Date.now() - (s.currentStartedAt || 0) > APPLICATION_TIMEOUT_MS) {
      await finish({ status: "failed", error: "timeout", details: {} }, { closeTab: false });
    } else {
      schedule(WATCHDOG_MS);
    }
    return;
  }

  const api = apiFor(s);
  let application;
  try {
    application = await api.next();
  } catch (e) {
    await handleApiError(e);
    return;
  }
  if (!application) {
    await setState({ lastError: null });
    schedule(IDLE_RETRY_MS);
    return;
  }

  try {
    await loadJobData(api);
  } catch (e) {
    await api
      .update(application.id, { status: "failed", error: "profile_unavailable: " + (e.code || e.message), details: {} })
      .catch(() => null);
    await handleApiError(e);
    return;
  }

  const tab = await chrome.tabs.create({ url: application.apply_url, active: false });
  await setState(
    Object.assign({}, CURRENT_CLEARED, {
      currentApplicationId: application.id,
      currentApplication: application,
      currentTabId: tab.id,
      currentStartedAt: Date.now(),
      currentPhase: "opening",
      lastError: null,
    }),
  );
  schedule(WATCHDOG_MS);

  const fresh = await chrome.tabs.get(tab.id).catch(() => null);
  if (fresh && fresh.status === "complete" && fresh.url && fresh.url !== "about:blank") await onTabComplete(tab.id);
}

async function onTabComplete(tabId) {
  const s = await getState();
  if (!s.currentApplicationId || tabId !== s.currentTabId || injecting.has(tabId)) return;

  if (s.currentPhase === "submitting") {
    await checkAfterSubmit(tabId, s.currentApplicationId);
    return;
  }
  if (s.currentPhase === "running") {
    const count = (s.currentNavigations || 0) + 1;
    if (count > MAX_NAVIGATIONS) {
      await finish({ status: "needs_user", error: "unexpected_navigation", details: {} });
      return;
    }
    await setState({ currentNavigations: count });
  }

  injecting.add(tabId);
  try {
    await setState({ currentPhase: "running" });
    await chrome.scripting.executeScript({ target: { tabId }, files: CONTENT_FILES });
    const job = await sessionGet();
    const payload = {
      application: s.currentApplication,
      profile: job.profile,
      resume: job.resume,
      coverLetter: s.currentApplication && s.currentApplication.cover_letter,
      dryRun: s.dryRun !== false,
    };
    await chrome.tabs.sendMessage(tabId, { type: "seera:run", payload });
  } catch (e) {
    await finish({ status: "failed", error: "inject_failed: " + (e && e.message ? e.message : String(e)), details: {} });
  } finally {
    injecting.delete(tabId);
  }
}

// The submit click navigated away, so the runner could not report. Look at the
// new page for a confirmation.
async function checkAfterSubmit(tabId, applicationId) {
  let state = null;
  try {
    await chrome.scripting.executeScript({ target: { tabId }, files: CHECK_FILES });
    const [injection] = await chrome.scripting.executeScript({
      target: { tabId },
      func: async () => {
        const F = globalThis.SeeraFill;
        const end = Date.now() + 10000;
        let st = F.pageState();
        while (!st.confirmed && Date.now() < end) {
          await F.sleep(500);
          st = F.pageState();
        }
        return st;
      },
    });
    state = injection && injection.result;
  } catch (_e) {
    state = null;
  }
  const details = { final_url: state && state.url };
  const only = { applicationId };
  if (state && state.confirmed) return finish({ status: "submitted", error: null, details }, only);
  if (state && state.captcha) {
    return finish({ status: "needs_user", error: "captcha", details: Object.assign(details, { captcha: state.captcha }) }, only);
  }
  if (state && state.errors > 0) return finish({ status: "needs_user", error: "validation_errors", details }, only);
  return finish({ status: "failed", error: "no_confirmation", details }, only);
}

async function finish(result, opts) {
  const o = opts || {};
  const s = await getState();
  const id = s.currentApplicationId;
  if (!id) return;
  if (o.applicationId !== undefined && o.applicationId !== id) return;

  const tabId = s.currentTabId;
  const application = s.currentApplication || {};
  await setState(CURRENT_CLEARED);

  const status = result.status || "failed";
  const body = { status, error: result.error || null, details: result.details || {} };
  let response = null;
  try {
    response = await apiFor(s).update(id, body);
  } catch (e) {
    if (e instanceof ApiError && (e.status === 401 || e.status === 403)) await handleApiError(e);
    else await setState({ lastError: e.code || "network" });
  }

  const posting = application.posting || {};
  const entry = {
    id,
    status,
    error: body.error,
    title: posting.title || "",
    company: posting.company || "",
    url: posting.url || application.apply_url || "",
    dryRun: Boolean(body.details.dry_run),
    at: Date.now(),
  };
  const history = [entry].concat(s.history || []).slice(0, HISTORY_SIZE);
  const patch = { history };
  if (response && response.today) patch.today = Object.assign({}, s.today || {}, response.today);
  await setState(patch);

  if (tabId) {
    if (status === "needs_user") {
      const tab = await chrome.tabs.update(tabId, { active: true }).catch(() => null);
      if (tab && tab.windowId !== undefined) await chrome.windows.update(tab.windowId, { focused: true }).catch(() => null);
      await chrome.action.setBadgeBackgroundColor({ color: "#c9a45c" });
      await chrome.action.setBadgeText({ text: "!" });
    } else if (o.closeTab !== false) {
      setTimeout(() => {
        chrome.tabs.remove(tabId).catch(() => null);
      }, CLOSE_TAB_AFTER_MS);
    }
  }

  const latest = await getState();
  if (latest.running) schedule(nextDelayMs());
}

// --- start / pause -------------------------------------------------------------

async function start() {
  await sessionClear();
  await setState({ running: true, pausedUntil: null, lastError: null });
  chrome.alarms.create(TICK_ALARM, { delayInMinutes: FIRST_TICK_MINUTES });
}

async function pause() {
  await setState({ running: false });
  await chrome.alarms.clear(TICK_ALARM);
}

// --- messages ------------------------------------------------------------------

async function onContentMessage(message, sender) {
  const s = await getState();
  if (!sender.tab || sender.tab.id !== s.currentTabId || !s.currentApplicationId) return { error: "not_current" };

  switch (message.type) {
    case "seera:answers": {
      try {
        return await apiFor(s).answers(s.currentApplicationId, message.questions || []);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) await handleApiError(e);
        return { error: e.code || "network" };
      }
    }
    case "seera:submitting":
      await setState({ currentPhase: "submitting" });
      return { ok: true };
    case "seera:navigate": {
      const count = (s.currentNavigations || 0) + 1;
      if (count > MAX_NAVIGATIONS) {
        await finish({ status: "needs_user", error: "too_many_navigations", details: {} });
        return { ok: false };
      }
      await setState({ currentPhase: "opening", currentNavigations: count });
      await chrome.tabs.update(sender.tab.id, { url: message.url });
      return { ok: true };
    }
    case "seera:result":
      await finish(message.result || {}, { applicationId: message.applicationId });
      return { ok: true };
    default:
      return { error: "unknown_message" };
  }
}

async function onPopupMessage(message) {
  switch (message.type) {
    case "seera:start":
      await start();
      return { ok: true };
    case "seera:pause":
      await pause();
      return { ok: true };
    default:
      return { error: "unknown_message" };
  }
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message || typeof message.type !== "string" || !message.type.startsWith("seera:")) return false;
  if (sender.id !== chrome.runtime.id) return false;
  const handler = sender.tab ? onContentMessage(message, sender) : onPopupMessage(message);
  handler.then(sendResponse, (e) => sendResponse({ error: String(e && e.message ? e.message : e) }));
  return true;
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === TICK_ALARM) tick();
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete") onTabComplete(tabId);
});

chrome.tabs.onRemoved.addListener(async (tabId) => {
  const s = await getState();
  if (s.currentApplicationId && tabId === s.currentTabId) {
    await finish({ status: "failed", error: "tab_closed", details: {} }, { closeTab: false });
  }
});

chrome.runtime.onInstalled.addListener(async (details) => {
  const s = await getState();
  const defaults = {};
  if (s.dryRun === undefined || details.reason === "install") defaults.dryRun = true;
  if (!s.origin) defaults.origin = DEFAULT_ORIGIN;
  if (s.running === undefined) defaults.running = false;
  if (!s.history) defaults.history = [];
  await setState(defaults);
});

chrome.runtime.onStartup.addListener(async () => {
  const s = await getState();
  if (s.running) chrome.alarms.create(TICK_ALARM, { delayInMinutes: FIRST_TICK_MINUTES });
});
