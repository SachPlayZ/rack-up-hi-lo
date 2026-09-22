import { act, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Countdown } from "./countdown";

describe("Countdown", () => {
  afterEach(() => vi.useRealTimers());

  it("tracks the onchain deadline and closes at zero", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(100_000));
    render(<Countdown deadline={103n} />);

    expect(screen.getByText("0:03")).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(3_000));
    expect(screen.getByText("0:00")).toBeInTheDocument();
    expect(screen.getByText("Bets closed")).toBeInTheDocument();
  });
});
