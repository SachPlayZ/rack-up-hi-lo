import { expect, test } from "@playwright/test";

test("player table renders without horizontal overflow", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Pick a name");
  await expect(page.getByRole("button", { name: "Sign in / create wallet" }).first()).toBeVisible();
  await expect(page.getByText("Players joined")).toBeVisible();
  await expect(page.getByText("Still in the game")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Players on the rail" })).toHaveCount(0);

  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
  expect(overflow).toBe(false);
});

test("admin desk requires the owner wallet", async ({ page }) => {
  await page.goto("/admin");
  await expect(page.getByRole("heading", { name: "Connect the table wallet." })).toBeVisible();
  await expect(page.getByRole("button", { name: "Sign in as admin" })).toBeVisible();
});
