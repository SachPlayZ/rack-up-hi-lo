import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { PoolBall } from "./pool-ball";

describe("PoolBall", () => {
  it("announces a settled number", () => {
    render(<PoolBall number={8} />);
    expect(screen.getByLabelText("Ball 8")).toHaveTextContent("8");
  });

  it("announces an active draw", () => {
    render(<PoolBall number={8} rolling />);
    expect(screen.getByLabelText("Drawing the next ball")).toHaveTextContent("?");
  });
});

