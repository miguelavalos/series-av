import { describe, expect, it } from "vitest";
import { seriesExternalQuery } from "./series.$seriesId";

describe("series detail external query", () => {
  it("does not append the year when the title already ends with it", () => {
    expect(seriesExternalQuery("Dororo 2019", 2019)).toBe("Dororo 2019");
    expect(seriesExternalQuery("Dororo", 2019)).toBe("Dororo 2019");
  });
});
