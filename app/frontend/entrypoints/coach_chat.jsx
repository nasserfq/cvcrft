import "../lib/sentry"; // Initialize Sentry first so it catches errors from everything below
import React from "react";
import { createRoot } from "react-dom/client";
import CoachChat from "../components/coach/CoachChat";
import "../lib/i18n";

// Track root instances by container
const rootMap = new WeakMap();

function renderApp() {
  const container = document.getElementById("coach-chat-root");
  if (!container || rootMap.has(container)) return;

  const root = createRoot(container);
  rootMap.set(container, root);
  root.render(
    <CoachChat
      chatId={container.dataset.chatId}
      messageUrl={container.dataset.messageUrl}
      acceptUrl={container.dataset.acceptUrl}
      rejectUrl={container.dataset.rejectUrl}
      initialMessages={JSON.parse(container.dataset.messages || "[]")}
      initialDraft={JSON.parse(container.dataset.draft || "{}")}
      initialProposals={JSON.parse(container.dataset.proposals || "[]")}
    />
  );
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", renderApp);
} else {
  renderApp();
}

// Handle Turbo navigation - use turbo:render which fires after DOM is stable
document.addEventListener("turbo:render", renderApp);
