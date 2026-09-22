"use client";

export default function ErrorBoundary({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main className="centered-page">
      <section className="notice-card" role="alert">
        <p className="eyebrow">Table fault</p>
        <h1>The rack broke badly.</h1>
        <p>Refresh the table state and try that shot again.</p>
        <button className="button button--ivory" type="button" onClick={reset}>
          Reload table
        </button>
      </section>
    </main>
  );
}

