import React, { useEffect, useMemo, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { createConsumer } from "@rails/actioncable";
import DraftPreview from "./DraftPreview";
import ProposalCard from "./ProposalCard";
import LocationCombobox from "../cv-builder/LocationCombobox";
import MobileDatePicker from "../cv-builder/MobileDatePicker";
import { getCities, getCountries } from "../cv-builder/locationData";

const muted = { color: "rgba(238,243,238,0.7)" };

// With no chunk or `done` for this long the stream is treated as dropped.
const STREAM_TIMEOUT_MS = 60000;

export default function CoachChat({ chatId, messageUrl, acceptUrl, rejectUrl, initialMessages, initialDraft, initialProposals }) {
  const { t } = useTranslation();
  const [messages, setMessages] = useState(initialMessages);
  const [draft, setDraft] = useState(initialDraft);
  const [proposals, setProposals] = useState(initialProposals);
  const [pending, setPending] = useState(null); // streamed text of the reply in flight
  const [input, setInput] = useState("");
  // { text, kind: "send" | "timeout" | "other", retry: fn | null }, or null
  const [error, setError] = useState(null);
  const pendingRef = useRef(null); // `done` needs the text without waiting for a render
  const listRef = useRef(null);
  const watchdogRef = useRef(null);
  const busy = pending !== null;

  const clearWatchdog = () => {
    clearTimeout(watchdogRef.current);
    watchdogRef.current = null;
  };

  // (Re)armed on send and on every chunk; fires when the stream goes quiet.
  const armWatchdog = () => {
    clearWatchdog();
    watchdogRef.current = setTimeout(() => {
      watchdogRef.current = null;
      if (pendingRef.current === null) return;
      finish(null);
      // The message reached the server, so reloading picks up the reply if it landed after all.
      setError({ text: t("coach.timeout"), kind: "timeout", retry: () => window.location.reload() });
    }, STREAM_TIMEOUT_MS);
  };

  const finish = (text) => {
    clearWatchdog();
    pendingRef.current = null;
    setPending(null);
    if (text !== null) setMessages((list) => [...list, text]);
  };

  useEffect(() => clearWatchdog, []);

  useEffect(() => {
    const consumer = createConsumer();
    const subscription = consumer.subscriptions.create(
      { channel: "Coach::ChatChannel", chat_id: chatId },
      {
        received(data) {
          // Broadcasts can arrive out of order: each chunk is the whole text so far, so keep the longest,
          // and drop chunks that land after done.
          if (data.type === "chunk") {
            if (pendingRef.current === null || data.text.length <= pendingRef.current.length) return;
            pendingRef.current = data.text;
            setPending(data.text);
            armWatchdog();
          } else if (data.type === "done") {
            // A reply that lands after the timeout still counts; drop the timeout notice.
            setError((current) => (current?.kind === "timeout" ? null : current));
            finish({ id: data.message_id, role: "assistant", content: data.text, fields: data.fields || [] });
          } else if (data.type === "draft") {
            setDraft(data.draft);
          } else if (data.type === "proposal") {
            setProposals((list) => [...list, data.proposal]);
          } else if (data.type === "error") {
            setError({ text: t("coach.error"), kind: "other", retry: null });
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

  const send = (event) => {
    event.preventDefault();
    const content = input.trim();
    if (!content || busy) return;

    setInput("");
    post(content);
  };

  // Shared by the text box and the input boxes under a question.
  const post = async (content) => {
    setError(null);
    const localId = `local-${Date.now()}`;
    setMessages((list) => [...list, { id: localId, role: "user", content }]);
    pendingRef.current = "";
    setPending("");
    armWatchdog();

    // Nothing reached the server: take the bubble back and put the text in the box so it isn't lost.
    const failed = (text, upgrade = null) => {
      finish(null);
      setMessages((list) => list.filter((m) => m.id !== localId));
      setInput((current) => (current.trim() ? current : content));
      setError({
        text,
        kind: "send",
        upgrade,
        retry: () => {
          setInput("");
          post(content);
        },
      });
    };

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
        // The 429 daily cap and the 402 out-of-credits carry their own message; 402 also links to /credits.
        const body = await response.json().catch(() => ({}));
        const upgrade = body.upgrade_url ? { url: body.upgrade_url, label: body.upgrade_label } : null;
        failed(body.error || t("coach.error"), upgrade);
      }
    } catch {
      failed(t("coach.error"));
    }
  };

  const settled = (id, ok) => {
    if (id) setProposals((list) => list.filter((p) => p.id !== id));
    setError(ok ? null : { text: t("coach.error"), kind: "other", retry: null });
  };

  // Stacked on mobile, chat beside the preview on desktop.
  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)] items-start">
      <section className="glass sr-up rounded-[32px] p-4 sm:p-6 flex flex-col gap-4" style={{ minHeight: "70dvh" }}>
        <header className="flex items-center gap-2.5 px-2">
          <span className="sr-dot w-2 h-2 rounded-full bg-primary"></span>
          <h1 className="m-0 text-[20px] font-semibold">{t("coach.title")}</h1>
        </header>

        <ol ref={listRef} className="list-none m-0 p-1 flex-1 flex flex-col gap-3 overflow-y-auto" style={{ maxHeight: "60dvh" }}>
          {messages.map((message, i) => (
            <Bubble key={message.id} role={message.role}>
              {message.content}
              {/* Only the latest question's boxes; answered ones would be stale. */}
              {!busy && i === messages.length - 1 && message.fields?.length > 0 && (
                <Fields fields={message.fields} onSubmit={post} />
              )}
            </Bubble>
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
          <div className="glass-soft sr-up m-0 rounded-2xl px-5 py-3 text-[15px] flex flex-wrap items-center justify-between gap-3" style={{ color: "#d6b877" }} role="alert">
            <span className="min-w-0">{error.text}</span>
            {error.upgrade && (
              <a
                href={error.upgrade.url}
                className="sr-btn sr-primary flex-none min-h-[44px] px-4 rounded-2xl font-semibold text-[14px] inline-flex items-center"
              >
                {error.upgrade.label}
              </a>
            )}
            {error.retry && !error.upgrade && (
              <button
                type="button"
                onClick={error.retry}
                disabled={busy}
                className="sr-btn sr-primary flex-none min-h-[44px] px-4 rounded-2xl font-semibold text-[14px] border-0 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {t("coach.retry")}
              </button>
            )}
          </div>
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

const boxClass = "glass-soft w-full rounded-xl px-3 py-2 text-[16px] border-0 outline-none";

// Input boxes under a coach question; the answers go out as one "Label: value" message.
// Older messages stored plain label strings.
function Fields({ fields, onSubmit }) {
  const { t } = useTranslation();
  const boxes = fields.map((f) => (typeof f === "string" ? { label: f, type: "text" } : f));
  const [values, setValues] = useState(() => boxes.map(() => ({ text: "", start: "", end: "", current: false })));
  const set = (i, patch) => setValues((list) => list.map((v, j) => (j === i ? { ...v, ...patch } : v)));
  const countries = useMemo(() => getCountries(), []);
  const country = values[boxes.findIndex((b) => b.type === "country")]?.text;
  const cities = useMemo(() => getCities(country), [country]);

  const answer = (box, v) => {
    if (box.type !== "date_range") return v.text.trim();
    if (!v.start) return "";
    return `${v.start} – ${v.current ? "Present" : v.end || "?"}`;
  };
  const filled = boxes.some((box, i) => answer(box, values[i]));

  const submit = (event) => {
    event.preventDefault();
    const content = boxes
      .map((box, i) => answer(box, values[i]) && `${box.label}: ${answer(box, values[i])}`)
      .filter(Boolean)
      .join("\n");
    onSubmit(content);
  };

  const input = (box, i) => {
    const v = values[i];
    if (box.type === "city" || box.type === "country") {
      return (
        <LocationCombobox
          value={v.text}
          onChange={(text) => set(i, { text })}
          onPick={(city) => {
            const c = boxes.findIndex((b) => b.type === "country");
            if (box.type === "city" && c >= 0 && !values[c].text.trim() && city.country) set(c, { text: city.country });
          }}
          options={box.type === "city" ? cities : countries}
          className={boxClass}
          placeholder={box.type === "city" ? "Riyadh" : "Saudi Arabia"}
        />
      );
    }
    if (box.type === "date_range") {
      return (
        <div className="flex flex-col gap-2">
          <MobileDatePicker value={v.start} onChange={(start) => set(i, { start })} placeholder={t("experience.start_date")} />
          <MobileDatePicker value={v.end} onChange={(end) => set(i, { end })} disabled={v.current} placeholder={t("experience.end_date")} />
          <label className="inline-flex items-center gap-2 text-[14px]">
            <input type="checkbox" checked={v.current} onChange={(e) => set(i, { current: e.target.checked })} className="w-5 h-5" />
            {t("experience.present")}
          </label>
        </div>
      );
    }
    return (
      <input
        type={box.type === "email" || box.type === "tel" ? box.type : "text"}
        value={v.text}
        onChange={(event) => set(i, { text: event.target.value })}
        autoFocus={i === 0}
        maxLength={200}
        dir="auto"
        className={boxClass}
        style={{ color: "#eef3ee" }}
      />
    );
  };

  return (
    <form onSubmit={submit} className="mt-3 flex flex-col gap-3 whitespace-normal">
      {boxes.map((box, i) => (
        <div key={i} className="flex flex-col gap-1">
          <span className="text-[13px]" style={muted}>{box.label}</span>
          {input(box, i)}
        </div>
      ))}
      <button
        type="submit"
        disabled={!filled}
        className="sr-btn sr-primary self-start min-h-[44px] px-5 rounded-2xl font-semibold text-[15px] border-0 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {t("coach.send")}
      </button>
    </form>
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
