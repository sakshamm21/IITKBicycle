import { describe, expect, it } from "vitest";

import { APP_NAME, bikeShortCodeSchema, lockCodeSchema, userRoleSchema } from "./index";

describe("shared constants and schemas", () => {
  it("names the app", () => {
    expect(APP_NAME).toBe("IITK Bicycle");
  });

  it("accepts bike labels like K-042 and rejects malformed ones", () => {
    expect(bikeShortCodeSchema.safeParse("K-042").success).toBe(true);
    expect(bikeShortCodeSchema.safeParse("k-42").success).toBe(false);
  });

  it("accepts only 4-digit lock codes", () => {
    expect(lockCodeSchema.safeParse("0731").success).toBe(true);
    expect(lockCodeSchema.safeParse("731").success).toBe(false);
    expect(lockCodeSchema.safeParse("12a4").success).toBe(false);
  });

  it("knows all database roles", () => {
    expect(userRoleSchema.options).toEqual(["rider", "attendant", "college_admin", "super_admin"]);
  });
});
