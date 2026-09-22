import Link from "next/link";

export default function NotFound() {
  return (
    <main className="centered-page">
      <section className="notice-card">
        <p className="eyebrow">Scratch</p>
        <h1>That table does not exist.</h1>
        <Link className="button button--ivory" href="/">
          Return to the game
        </Link>
      </section>
    </main>
  );
}

