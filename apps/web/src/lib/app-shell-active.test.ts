import { describe, expect, it } from "vitest";
import { isActiveAppShellLink } from "@avalsys/apps-av-web";

describe("shared app shell active links", () => {
  it("matches localized links by pathname", () => {
    expect(isActiveAppShellLink("/search?lang=es", "/search")).toBe(true);
    expect(isActiveAppShellLink("/library?lang=ca", "/library")).toBe(true);
    expect(isActiveAppShellLink("/settings?lang=fr", "/settings")).toBe(true);
  });

  it("does not mark home active for every route", () => {
    expect(isActiveAppShellLink("/?lang=es", "/library")).toBe(false);
    expect(isActiveAppShellLink("/?lang=es", "/")).toBe(true);
  });
});
