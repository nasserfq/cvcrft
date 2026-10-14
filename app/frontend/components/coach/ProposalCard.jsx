import React, { useState } from "react";
import { useTranslation } from "react-i18next";

const muted = { color: "rgba(238,243,238,0.7)" };
const accent = { color: "#d6b877" };

// Responsibilities are a list; the summary is one string.
function Value({ value }) {
  if (Array.isArray(value)) {
    return (
      <ul className="m-0 ps-5 list-disc">
        {value.map((line, i) => <li key={i}>{line}</li>)}
      </ul>
    );
  }
  return <p className="m-0 whitespace-pre-wrap">{value || "—"}</p>;
}

// One rewrite the coach suggested; Accept writes it into the draft, Reject drops it.
export default function ProposalCard({ proposal, acceptUrl, rejectUrl, onSettled }) {
  const { t } = useTranslation();
  const [busy, setBusy] = useState(false);

  const settle = async (url) => {
    setBusy(true);
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.getAttribute("content"),
        },
        body: JSON.stringify({ proposal_id: proposal.id }),
      });
      // 404/422 mean the server already dropped it, so the card goes either way.
      onSettled(proposal.id, response.ok);
    } catch {
      setBusy(false);
      onSettled(null, false);
    }
  };

  return (
    <li className="glass-soft sr-up rounded-[22px] p-4 flex flex-col gap-3 text-[14px]">
      <div dir="auto" className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-1">
          <span className="text-[12px] font-semibold uppercase tracking-wide" style={muted}>{t("coach.proposal.before")}</span>
          <div style={muted}><Value value={proposal.before} /></div>
        </div>
        <div className="flex flex-col gap-1">
          <span className="text-[12px] font-semibold uppercase tracking-wide" style={accent}>{t("coach.proposal.after")}</span>
          <Value value={proposal.after} />
        </div>
      </div>
      <div className="flex flex-wrap gap-2 justify-end">
        <button
          type="button"
          disabled={busy}
          onClick={() => settle(rejectUrl)}
          className="glass-soft min-h-[44px] px-5 rounded-2xl font-semibold text-[14px] border-0 cursor-pointer disabled:opacity-50"
          style={{ color: "#eef3ee" }}
        >
          {t("coach.proposal.reject")}
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={() => settle(acceptUrl)}
          className="sr-btn sr-primary min-h-[44px] px-5 rounded-2xl font-semibold text-[14px] border-0 cursor-pointer disabled:opacity-50"
        >
          {t("coach.proposal.accept")}
        </button>
      </div>
    </li>
  );
}
