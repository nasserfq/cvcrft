// Popup: pairing, start/pause, dry-run, today's count and the last results.
import { ALLOWED_ORIGINS, normaliseOrigin } from "./config.js";
import { createApi } from "./api.js";
import { errorText, t } from "./i18n.js";

const $ = (id) => document.getElementById(id);

function applyStrings() {
  document.querySelectorAll("[data-t]").forEach((el) => {
    el.textContent = t(el.dataset.t);
  });
  $("token").placeholder = t("token_placeholder");
}

function showMessage(text, isError) {
  const el = $("message");
  el.hidden = !text;
  el.textContent = text || "";
  el.classList.toggle("error", Boolean(isError));
}

function renderHistory(history) {
  const list = $("history");
  list.replaceChildren();
  if (!history || history.length === 0) {
    const li = document.createElement("li");
    li.className = "muted small";
    li.textContent = t("no_recent");
    list.append(li);
    return;
  }
  for (const item of history) {
    const li = document.createElement("li");
    const link = document.createElement("a");
    link.href = item.url || "#";
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.textContent = [item.title, item.company].filter(Boolean).join(" · ") || "#" + item.id;
    const status = document.createElement("span");
    status.className = "status " + item.status;
    status.textContent = t("status_" + item.status) + (item.dryRun ? " · " + t("dry_run_short") : "");
    li.append(link, status);
    list.append(li);
  }
}

function render(state) {
  const paired = Boolean(state.token);
  $("pair").hidden = paired;
  $("paired").hidden = !paired;

  const origin = normaliseOrigin(state.origin);
  $("origin").value = origin;
  $("dashboard").href = origin + "/auto_apply";

  if (paired) {
    const user = state.user || {};
    $("who").textContent = t("paired_as", { name: user.name || user.email || "" });
    $("state").textContent = state.running ? t("running") : t("paused");
    $("state").classList.toggle("on", Boolean(state.running));
    $("toggle").textContent = state.running ? t("pause") : t("start");
    $("dryRun").checked = state.dryRun !== false;
    const today = state.today || {};
    $("today").textContent = t("today", { submitted: today.submitted || 0, remaining: today.remaining ?? "–" });
  }

  if (state.lastError) {
    const soft = ["daily_cap_reached", "rate_limited"].includes(state.lastError);
    showMessage(errorText(state.lastError), !soft);
  } else if (state.currentApplication && state.currentApplication.posting) {
    showMessage(t("working_on", { title: state.currentApplication.posting.title }), false);
  } else {
    showMessage("");
  }
  renderHistory(state.history);
}

async function refreshMe(state) {
  if (!state.token) return;
  try {
    const me = await createApi({ origin: state.origin, token: state.token }).me();
    await chrome.storage.local.set({ user: me.user, today: me.today });
  } catch (e) {
    if (e.status === 401) {
      await chrome.storage.local.set({ token: null, user: null, running: false, lastError: "unauthorized" });
      await chrome.runtime.sendMessage({ type: "seera:pause" });
    } else {
      await chrome.storage.local.set({ lastError: e.code || "network" });
    }
  }
}

async function savePairing() {
  const token = $("token").value.trim();
  if (!token) return;
  const state = await chrome.storage.local.get(null);
  $("save").disabled = true;
  $("save").textContent = t("saving");
  try {
    const me = await createApi({ origin: state.origin, token }).me();
    await chrome.storage.local.set({ token, user: me.user, today: me.today, lastError: null });
    $("token").value = "";
  } catch (e) {
    showMessage(errorText(e.code || "network"), true);
  } finally {
    $("save").disabled = false;
    $("save").textContent = t("save");
  }
}

async function init() {
  applyStrings();
  for (const origin of ALLOWED_ORIGINS) {
    const opt = document.createElement("option");
    opt.value = origin;
    opt.textContent = origin;
    $("origin").append(opt);
  }

  chrome.action.setBadgeText({ text: "" });

  $("save").addEventListener("click", savePairing);
  $("token").addEventListener("keydown", (e) => {
    if (e.key === "Enter") savePairing();
  });
  $("forget").addEventListener("click", async () => {
    await chrome.runtime.sendMessage({ type: "seera:pause" });
    await chrome.storage.local.set({ token: null, user: null, today: null, lastError: null });
  });
  $("toggle").addEventListener("click", async () => {
    const state = await chrome.storage.local.get("running");
    await chrome.runtime.sendMessage({ type: state.running ? "seera:pause" : "seera:start" });
  });
  $("dryRun").addEventListener("change", (e) => chrome.storage.local.set({ dryRun: e.target.checked }));
  $("origin").addEventListener("change", async (e) => {
    await chrome.runtime.sendMessage({ type: "seera:pause" });
    await chrome.storage.local.set({ origin: normaliseOrigin(e.target.value), token: null, user: null, today: null });
  });

  chrome.storage.onChanged.addListener(async (_changes, area) => {
    if (area === "local") render(await chrome.storage.local.get(null));
  });

  const state = await chrome.storage.local.get(null);
  render(state);
  await refreshMe(state);
}

init();
