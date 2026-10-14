import React, { useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { createConsumer } from "@rails/actioncable";
import DraftPreview from "./DraftPreview";
import ProposalCard from "./ProposalCard";

const muted = { color: "rgba(238,243,238,0.7)" };

export default function CoachChat({ chatId, messageUrl, acceptUrl, rejectUrl, initialMessages, initialDraft, initialProposals }) {
  const { t } = useTranslation();
  const [messages, setMessages] = useState(initialMessages);
  const [draft, setDraft] = useState(initialDraft);
  const [proposals, setProposals] = useState(initialProposals);
  const [pending, setPending] = useState(null); // streamed text of the reply in flight
  const [input, setInput] = useState("");
  const [error, setError] = useState(null); // message to show, or null
  const pendingRef = useRef(null); // `done` needs the text without waiting for a render
  const listRef = useRef(null);
  const busy = pending !== null;

  const finish = (text) => {
    pendingRef.current = null;
    setPending(null);
    if (text !== null) setMessages((list) => [...list, text]);
  };

  useEffect(() => {
    const consumer = createConsumer();
    const subscription = consumer.subscriptions.create(
      { channel: "Coach::ChatChannel", chat_id: chatId },
      {
        received(data) {
          if (data.type === "chunk") {
            pendingRef.current = (pendingRef.current || "") + data.text;
            setPending(pendingRef.current);
          } else if (data.type === "done") {
            finish({ id: data.message_id, role: "assistant", content: pendingRef.current || "" });
          } else if (data.type === "draft") {
            setDraft(data.draft);
          } else if (data.type === "proposal") {
            setProposals((list) => [...list, data.proposal]);
          } else if (data.type === "error") {
            setError(t("coach.error"));
            finish(null);
          }
        },
      }
    );
    return () => {
      subscription.unsubscribe();
      consumer.disconnect();
    };
  }, [chatId]);

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, pending]);

  const send = async (event) => {
    event.preventDefault();
    const content = input.trim();
    if (!content || busy) return;

    setError(null);
    setInput("");
    setMessages((list) => [...list, { id: `local-${Date.now()}`, role: "user", content }]);
    pendingRef.current = "";
    setPending("");

    try {
      const response = await fetch(messageUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.getAttribute("content"),
        },
        body: JSON.stringify({ content }),
      });
      if (!response.ok) {
        // The 429 daily cap carries its own message.
        const body = await response.json().catch(() => ({}));
        setError(body.error || t("coach.error"));
        finish(null);
      }
    } catch {
      setError(t("coach.error"));
      finish(null);
    }
  };

  const settled = (id, ok) => {
    if (id) setProposals((list) => list.filter((p) => p.id !== id));
    setError(ok ? null : t("coach.error"));
  };

  // Stacked on mobile, chat beside the preview on desktop.
  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)] items-start">
      <section className="glass sr-up rounded-[32px] p-4 sm:p-6 flex flex-col gap-4" style={{ minHeight: "70vh" }}>
        <header className="flex items-center gap-2.5 px-2">
          <span className="sr-dot w-2 h-2 rounded-full bg-primary"></span>
          <h1 className="m-0 text-[20px] font-semibold">{t("coach.title")}</h1>
        </header>

        <ol ref={listRef} className="list-none m-0 p-1 flex-1 flex flex-col gap-3 overflow-y-auto" style={{ maxHeight: "60vh" }}>
          {messages.map((message) => (
            <Bubble key={message.id} role={message.role}>{message.content}</Bubble>
          ))}
          {busy && (
            <Bubble role="assistant">
              {pending || (
                <span className="inline-flex items-center gap-2" style={muted}>
                  <span className="sr-dot w-2 h-2 rounded-full bg-primary"></span>
                  {t("coach.thinking")}
                </span>
              )}
            </Bubble>
          )}
        </ol>

        {proposals.length > 0 && (
          <ul className="list-none m-0 p-0 flex flex-col gap-3">
            {proposals.map((proposal) => (
              <ProposalCard key={proposal.id} proposal={proposal} acceptUrl={acceptUrl} rejectUrl={rejectUrl} onSettled={settled} />
            ))}
          </ul>
        )}

        {error && (
          <p className="glass-soft sr-up m-0 rounded-2xl px-5 py-3 text-[15px]" style={{ color: "#d6b877" }} role="alert">
            {error}
          </p>
        )}

        <form onSubmit={send} className="glass-soft rounded-[24px] p-2 flex items-end gap-2">
          <textarea
            value={input}
            onChange={(event) => setInput(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) send(event);
            }}
            placeholder={t("coach.placeholder")}
            disabled={busy}
            rows={2}
            maxLength={20000}
            dir="auto"
            className="flex-1 min-w-0 resize-none bg-transparent border-0 outline-none px-3 py-2 text-[16px] disabled:opacity-60"
            style={{ color: "#eef3ee" }}
          />
          <button
            type="submit"
            disabled={busy || !input.trim()}
            className="sr-btn sr-primary flex-none min-h-[48px] px-5 rounded-2xl font-semibold text-[15px] border-0 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {t("coach.send")}
          </button>
        </form>
      </section>
      <DraftPreview draft={draft} />
    </div>
  );
}

function Bubble({ role, children }) {
  const mine = role === "user";
  return (
    <li
      dir="auto"
      className={`sr-up max-w-[85%] rounded-[22px] px-4 py-3 text-[15px] whitespace-pre-wrap break-words ${
        mine ? "self-end sr-primary" : "self-start glass-soft"
      }`}
    >
      {children}
    </li>
  );
}
